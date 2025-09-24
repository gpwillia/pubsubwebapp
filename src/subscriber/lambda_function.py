import json
import boto3
import logging
import os
import uuid
from datetime import datetime
from typing import Dict, Any, List
from botocore.exceptions import ClientError, BotoCoreError
from config import Config

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    AWS Lambda handler for processing SNS messages.
    
    Args:
        event: Lambda event containing SNS records
        context: Lambda context object
        
    Returns:
        Dict containing processing results
    """
    request_id = context.aws_request_id
    start_time = datetime.utcnow()
    
    logger.info(f"Processing SNS event {request_id} with {len(event.get('Records', []))} records")
    
    successful_records = 0
    failed_records = 0
    processing_results = []
    
    try:
        # Process each SNS record
        for record in event.get('Records', []):
            try:
                result = process_sns_record(record, context)
                processing_results.append(result)
                successful_records += 1
                
            except MessageProcessingError as e:
                logger.error(f"Failed to process record: {str(e)}")
                failed_records += 1
                processing_results.append({
                    'status': 'failed',
                    'error': str(e),
                    'record_id': record.get('Sns', {}).get('MessageId', 'unknown')
                })
                
            except Exception as e:
                logger.exception(f"Unexpected error processing record: {str(e)}")
                failed_records += 1
                processing_results.append({
                    'status': 'error',
                    'error': str(e),
                    'record_id': record.get('Sns', {}).get('MessageId', 'unknown')
                })
        
        # Record metrics
        record_metrics(successful_records, failed_records, start_time, context)
        
        # Log summary
        logger.info(f"Processing complete for {request_id}: {successful_records} successful, {failed_records} failed")
        
        # Return results (for batch processing scenarios)
        return {
            'statusCode': 200 if failed_records == 0 else 207,  # 207 for partial success
            'processedRecords': len(processing_results),
            'successfulRecords': successful_records,
            'failedRecords': failed_records,
            'results': processing_results,
            'requestId': request_id
        }
        
    except Exception as e:
        logger.exception(f"Critical error in lambda_handler for {request_id}: {str(e)}")
        record_metrics(successful_records, len(event.get('Records', [])) - successful_records, start_time, context, error=True)
        
        # For SNS Lambda triggers, we should not return error responses
        # as it can cause message redelivery loops
        return {
            'statusCode': 500,
            'error': 'Critical processing error',
            'requestId': request_id
        }


def process_sns_record(record: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Process a single SNS record.
    
    Args:
        record: SNS record from Lambda event
        context: Lambda context
        
    Returns:
        Dict containing processing result
        
    Raises:
        MessageProcessingError: If processing fails
    """
    try:
        sns_data = record.get('Sns', {})
        message_id = sns_data.get('MessageId')
        
        # Extract message content
        message_body = sns_data.get('Message', '{}')
        message_attributes = sns_data.get('MessageAttributes', {})
        
        # Parse message
        try:
            parsed_message = json.loads(message_body)
        except json.JSONDecodeError as e:
            raise MessageProcessingError(f"Invalid JSON in SNS message {message_id}: {str(e)}")
        
        # Extract metadata
        correlation_id = extract_correlation_id(message_attributes, parsed_message)
        source = extract_source(message_attributes, parsed_message)
        
        logger.info(f"Processing message {message_id} with correlation ID {correlation_id} from {source}")
        
        # Validate message structure
        validate_message_structure(parsed_message, message_id)
        
        # Process the message based on its type or content
        processing_result = process_message_content(parsed_message, correlation_id, message_id, context)
        
        # Store processing result (optional - for audit trail)
        store_processing_result(message_id, correlation_id, parsed_message, processing_result, context)
        
        return {
            'status': 'success',
            'messageId': message_id,
            'correlationId': correlation_id,
            'source': source,
            'processingResult': processing_result,
            'timestamp': datetime.utcnow().isoformat()
        }
        
    except MessageProcessingError:
        raise
    except Exception as e:
        raise MessageProcessingError(f"Unexpected error processing SNS record: {str(e)}")


def extract_correlation_id(message_attributes: Dict[str, Any], parsed_message: Dict[str, Any]) -> str:
    """Extract correlation ID from message attributes or message body."""
    # Try message attributes first
    if 'CorrelationId' in message_attributes:
        return message_attributes['CorrelationId'].get('Value', str(uuid.uuid4()))
    
    # Try message body
    if isinstance(parsed_message, dict) and 'correlationId' in parsed_message:
        return parsed_message['correlationId']
    
    # Generate new correlation ID if not found
    return str(uuid.uuid4())


def extract_source(message_attributes: Dict[str, Any], parsed_message: Dict[str, Any]) -> str:
    """Extract source information from message."""
    # Try message attributes first
    if 'Source' in message_attributes:
        return message_attributes['Source'].get('Value', 'unknown')
    
    # Try message body
    if isinstance(parsed_message, dict) and 'source' in parsed_message:
        return parsed_message['source']
    
    return 'unknown'


def validate_message_structure(message: Dict[str, Any], message_id: str) -> None:
    """
    Validate the structure of the parsed message.
    
    Args:
        message: Parsed message data
        message_id: SNS message ID
        
    Raises:
        MessageProcessingError: If validation fails
    """
    if not isinstance(message, dict):
        raise MessageProcessingError(f"Message {message_id} must be a JSON object")
    
    # Check for required fields based on your business logic
    required_fields = ['data']  # Adjust based on your message structure
    
    for field in required_fields:
        if field not in message:
            raise MessageProcessingError(f"Message {message_id} missing required field: {field}")
    
    # Additional validation logic can be added here
    message_size = len(json.dumps(message).encode('utf-8'))
    if message_size > Config.MAX_MESSAGE_SIZE:
        raise MessageProcessingError(f"Message {message_id} size ({message_size} bytes) exceeds limit")


def process_message_content(message: Dict[str, Any], correlation_id: str, message_id: str, context) -> Dict[str, Any]:
    """
    Process the actual message content based on business logic.
    
    Args:
        message: Parsed message data
        correlation_id: Message correlation ID
        message_id: SNS message ID
        context: Lambda context
        
    Returns:
        Dict containing processing result
    """
    try:
        # Extract the actual data from the message
        data = message.get('data', {})
        
        # Example business logic - customize based on your needs
        if isinstance(data, dict) and 'message' in data:
            # Process text message
            result = process_text_message(data['message'], correlation_id)
        elif isinstance(data, dict) and 'order' in data:
            # Process order message
            result = process_order_message(data['order'], correlation_id)
        elif isinstance(data, dict) and 'event' in data:
            # Process event message
            result = process_event_message(data['event'], correlation_id)
        else:
            # Generic processing
            result = process_generic_message(data, correlation_id)
        
        logger.info(f"Successfully processed message content for {correlation_id}")
        
        return {
            'type': result.get('type', 'generic'),
            'processed': True,
            'details': result,
            'processingTime': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error processing message content for {correlation_id}: {str(e)}")
        raise MessageProcessingError(f"Failed to process message content: {str(e)}")


def process_text_message(text_content: str, correlation_id: str) -> Dict[str, Any]:
    """Process a text message."""
    logger.debug(f"Processing text message for {correlation_id}: {text_content[:100]}...")
    
    # Example: word count, sentiment analysis, etc.
    word_count = len(text_content.split())
    char_count = len(text_content)
    
    return {
        'type': 'text',
        'wordCount': word_count,
        'charCount': char_count,
        'processed': True
    }


def process_order_message(order_data: Dict[str, Any], correlation_id: str) -> Dict[str, Any]:
    """Process an order message."""
    logger.debug(f"Processing order message for {correlation_id}")
    
    # Example order processing logic
    order_id = order_data.get('id', 'unknown')
    total_amount = order_data.get('total', 0)
    
    return {
        'type': 'order',
        'orderId': order_id,
        'totalAmount': total_amount,
        'processed': True
    }


def process_event_message(event_data: Dict[str, Any], correlation_id: str) -> Dict[str, Any]:
    """Process an event message."""
    logger.debug(f"Processing event message for {correlation_id}")
    
    # Example event processing logic
    event_type = event_data.get('type', 'unknown')
    timestamp = event_data.get('timestamp', datetime.utcnow().isoformat())
    
    return {
        'type': 'event',
        'eventType': event_type,
        'eventTimestamp': timestamp,
        'processed': True
    }


def process_generic_message(data: Any, correlation_id: str) -> Dict[str, Any]:
    """Process a generic message."""
    logger.debug(f"Processing generic message for {correlation_id}")
    
    return {
        'type': 'generic',
        'dataType': type(data).__name__,
        'processed': True
    }


def store_processing_result(message_id: str, correlation_id: str, message: Dict[str, Any], 
                          result: Dict[str, Any], context) -> None:
    """
    Store processing result for audit trail (optional).
    
    Args:
        message_id: SNS message ID
        correlation_id: Message correlation ID
        message: Original message data
        result: Processing result
        context: Lambda context
    """
    try:
        table_name = os.environ.get('PROCESSING_RESULTS_TABLE')
        if not table_name:
            logger.debug("No processing results table configured, skipping storage")
            return
        
        table = dynamodb.Table(table_name)
        
        item = {
            'messageId': message_id,
            'correlationId': correlation_id,
            'timestamp': datetime.utcnow().isoformat(),
            'functionName': context.function_name,
            'functionVersion': context.function_version,
            'requestId': context.aws_request_id,
            'processingResult': result,
            'messageSize': len(json.dumps(message).encode('utf-8')),
            'ttl': int((datetime.utcnow().timestamp() + Config.RESULT_TTL_DAYS * 24 * 3600))
        }
        
        table.put_item(Item=item)
        logger.debug(f"Stored processing result for {correlation_id}")
        
    except Exception as e:
        # Don't fail processing if storage fails
        logger.warning(f"Failed to store processing result for {correlation_id}: {str(e)}")


def record_metrics(successful_records: int, failed_records: int, start_time: datetime, 
                  context, error: bool = False) -> None:
    """
    Record custom CloudWatch metrics.
    
    Args:
        successful_records: Number of successfully processed records
        failed_records: Number of failed records
        start_time: Processing start time
        context: Lambda context
        error: Whether there was a critical error
    """
    try:
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds() * 1000  # Convert to milliseconds
        
        namespace = f"AWS/Lambda/PubSub/{os.environ.get('ENVIRONMENT', 'dev')}"
        
        metrics = [
            {
                'MetricName': 'MessagesProcessed',
                'Value': successful_records,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': context.function_name},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')},
                    {'Name': 'Status', 'Value': 'Success'}
                ]
            },
            {
                'MetricName': 'MessagesProcessed',
                'Value': failed_records,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': context.function_name},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')},
                    {'Name': 'Status', 'Value': 'Failed'}
                ]
            },
            {
                'MetricName': 'ProcessingLatency',
                'Value': duration,
                'Unit': 'Milliseconds',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': context.function_name},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')}
                ]
            }
        ]
        
        if error:
            metrics.append({
                'MetricName': 'CriticalErrors',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'FunctionName', 'Value': context.function_name},
                    {'Name': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'dev')}
                ]
            })
        
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=metrics
        )
        
    except Exception as e:
        # Don't fail the function if metrics recording fails
        logger.warning(f"Failed to record metrics: {str(e)}")


class MessageProcessingError(Exception):
    """Custom exception for message processing errors."""
    pass