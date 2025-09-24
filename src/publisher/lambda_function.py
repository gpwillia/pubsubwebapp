import json
import boto3
import logging
import os
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
from botocore.exceptions import ClientError, BotoCoreError
from config import Config

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# Initialize AWS clients
sns_client = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    AWS Lambda handler for publishing messages to SNS topic.
    
    Args:
        event: Lambda event containing message data
        context: Lambda context object
        
    Returns:
        Dict containing status and message details
    """
    correlation_id = str(uuid.uuid4())
    start_time = datetime.utcnow()
    
    # Add correlation ID to logger
    logger.info(f"Processing request {correlation_id}")
    
    try:
        # Validate input
        message_data = validate_input(event)
        
        # Prepare message
        message = prepare_message(message_data, correlation_id, context)
        
        # Publish to SNS
        response = publish_message(message, correlation_id)
        
        # Record success metrics
        record_metrics('Success', correlation_id, start_time)
        
        logger.info(f"Successfully published message {correlation_id} to SNS")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Message published successfully',
                'messageId': response['MessageId'],
                'correlationId': correlation_id,
                'timestamp': datetime.utcnow().isoformat()
            }),
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            }
        }
        
    except ValidationError as e:
        logger.error(f"Validation error for request {correlation_id}: {str(e)}")
        record_metrics('ValidationError', correlation_id, start_time)
        
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Invalid input',
                'message': str(e),
                'correlationId': correlation_id
            }),
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            }
        }
        
    except SNSPublishError as e:
        logger.error(f"SNS publish error for request {correlation_id}: {str(e)}")
        record_metrics('SNSError', correlation_id, start_time)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to publish message',
                'message': str(e),
                'correlationId': correlation_id
            }),
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            }
        }
        
    except Exception as e:
        logger.exception(f"Unexpected error for request {correlation_id}: {str(e)}")
        record_metrics('UnexpectedError', correlation_id, start_time)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'correlationId': correlation_id
            }),
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            }
        }


def validate_input(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Validate the incoming event data.
    
    Args:
        event: Lambda event data
        
    Returns:
        Validated message data
        
    Raises:
        ValidationError: If validation fails
    """
    try:
        # Handle API Gateway event structure
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event
            
        # Validate required fields
        if not isinstance(body, dict):
            raise ValidationError("Message body must be a JSON object")
            
        if 'message' not in body:
            raise ValidationError("Message field is required")
            
        # Validate message content
        message = body['message']
        if not message or (isinstance(message, str) and not message.strip()):
            raise ValidationError("Message cannot be empty")
            
        # Validate message size (SNS limit is 256KB)
        message_size = len(json.dumps(body).encode('utf-8'))
        if message_size > Config.MAX_MESSAGE_SIZE:
            raise ValidationError(f"Message size ({message_size} bytes) exceeds limit ({Config.MAX_MESSAGE_SIZE} bytes)")
            
        return body
        
    except json.JSONDecodeError as e:
        raise ValidationError(f"Invalid JSON in request body: {str(e)}")


def prepare_message(message_data: Dict[str, Any], correlation_id: str, context) -> Dict[str, Any]:
    """
    Prepare message with metadata for SNS publishing.
    
    Args:
        message_data: Original message data
        correlation_id: Unique correlation ID
        context: Lambda context
        
    Returns:
        Formatted message with metadata
    """
    return {
        'correlationId': correlation_id,
        'timestamp': datetime.utcnow().isoformat(),
        'source': 'publisher-lambda',
        'requestId': context.aws_request_id,
        'data': message_data,
        'metadata': {
            'functionName': context.function_name,
            'functionVersion': context.function_version,
            'memoryLimit': context.memory_limit_in_mb,
            'environment': os.environ.get('ENVIRONMENT', 'dev')
        }
    }


def publish_message(message: Dict[str, Any], correlation_id: str) -> Dict[str, Any]:
    """
    Publish message to SNS topic with retries.
    
    Args:
        message: Message to publish
        correlation_id: Unique correlation ID
        
    Returns:
        SNS publish response
        
    Raises:
        SNSPublishError: If publishing fails after retries
    """
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not topic_arn:
        raise SNSPublishError("SNS_TOPIC_ARN environment variable not set")
    
    message_body = json.dumps(message)
    message_attributes = {
        'CorrelationId': {
            'DataType': 'String',
            'StringValue': correlation_id
        },
        'Source': {
            'DataType': 'String',
            'StringValue': 'publisher-lambda'
        },
        'Environment': {
            'DataType': 'String',
            'StringValue': os.environ.get('ENVIRONMENT', 'dev')
        }
    }
    
    max_retries = Config.MAX_RETRIES
    
    for attempt in range(max_retries + 1):
        try:
            logger.debug(f"Publishing message attempt {attempt + 1}/{max_retries + 1} for {correlation_id}")
            
            response = sns_client.publish(
                TopicArn=topic_arn,
                Message=message_body,
                MessageAttributes=message_attributes,
                Subject=f"Message from Publisher Lambda - {correlation_id}"
            )
            
            logger.info(f"Message published successfully on attempt {attempt + 1}, MessageId: {response['MessageId']}")
            return response
            
        except (ClientError, BotoCoreError) as e:
            error_code = getattr(e.response, 'Error', {}).get('Code', 'Unknown') if hasattr(e, 'response') else 'Unknown'
            logger.warning(f"Attempt {attempt + 1} failed for {correlation_id}: {error_code} - {str(e)}")
            
            if attempt == max_retries:
                raise SNSPublishError(f"Failed to publish message after {max_retries + 1} attempts: {str(e)}")
                
            # Exponential backoff (handled by boto3 retry logic)
            continue


def record_metrics(metric_type: str, correlation_id: str, start_time: datetime) -> None:
    """
    Record custom CloudWatch metrics.
    
    Args:
        metric_type: Type of metric (Success, ValidationError, SNSError, UnexpectedError)
        correlation_id: Unique correlation ID
        start_time: Request start time
    """
    try:
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds() * 1000  # Convert to milliseconds
        
        namespace = f"AWS/Lambda/PubSub/{os.environ.get('ENVIRONMENT', 'dev')}"
        
        metrics = [
            {
                'MetricName': 'MessagePublishCount',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'publisher')},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')},
                    {'Name': 'MetricType', 'Value': metric_type}
                ]
            },
            {
                'MetricName': 'MessagePublishLatency',
                'Value': duration,
                'Unit': 'Milliseconds',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'publisher')},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')}
                ]
            }
        ]
        
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=metrics
        )
        
    except Exception as e:
        # Don't fail the function if metrics recording fails
        logger.warning(f"Failed to record metrics for {correlation_id}: {str(e)}")


class ValidationError(Exception):
    """Custom exception for input validation errors."""
    pass


class SNSPublishError(Exception):
    """Custom exception for SNS publishing errors."""
    pass