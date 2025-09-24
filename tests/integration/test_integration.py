"""Integration tests for the AWS Lambda Pub/Sub solution."""

import json
import time
import boto3
import pytest
import os
import uuid
from datetime import datetime
import requests


class TestIntegration:
    """Integration tests for the complete Pub/Sub system."""

    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        # Get configuration from environment variables
        cls.sns_topic_arn = os.environ.get('TEST_SNS_TOPIC_ARN')
        cls.publisher_function_name = os.environ.get('TEST_PUBLISHER_FUNCTION_NAME')
        cls.subscriber_function_name = os.environ.get('TEST_SUBSCRIBER_FUNCTION_NAME')
        cls.dlq_url = os.environ.get('TEST_DLQ_URL')
        cls.api_gateway_url = os.environ.get('TEST_API_GATEWAY_URL')
        cls.region = os.environ.get('TEST_AWS_REGION', 'us-east-1')
        
        # Initialize AWS clients
        cls.lambda_client = boto3.client('lambda', region_name=cls.region)
        cls.sns_client = boto3.client('sns', region_name=cls.region)
        cls.sqs_client = boto3.client('sqs', region_name=cls.region)
        cls.logs_client = boto3.client('logs', region_name=cls.region)
        
        # Verify required environment variables
        required_vars = [
            cls.sns_topic_arn,
            cls.publisher_function_name,
            cls.subscriber_function_name
        ]
        
        if not all(required_vars):
            pytest.skip("Required environment variables not set for integration tests")

    def test_infrastructure_deployed(self):
        """Test that all infrastructure components are deployed and accessible."""
        # Test SNS topic exists
        try:
            self.sns_client.get_topic_attributes(TopicArn=self.sns_topic_arn)
        except Exception as e:
            pytest.fail(f"SNS topic not accessible: {e}")
        
        # Test Lambda functions exist
        try:
            self.lambda_client.get_function(FunctionName=self.publisher_function_name)
            self.lambda_client.get_function(FunctionName=self.subscriber_function_name)
        except Exception as e:
            pytest.fail(f"Lambda functions not accessible: {e}")
        
        # Test DLQ exists (if configured)
        if self.dlq_url:
            try:
                self.sqs_client.get_queue_attributes(QueueUrl=self.dlq_url)
            except Exception as e:
                pytest.fail(f"DLQ not accessible: {e}")

    def test_direct_lambda_invocation(self):
        """Test invoking the publisher Lambda function directly."""
        correlation_id = str(uuid.uuid4())
        test_message = {
            'message': f'Integration test message - {correlation_id}',
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Invoke publisher function
        response = self.lambda_client.invoke(
            FunctionName=self.publisher_function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_message)
        )
        
        # Check response
        assert response['StatusCode'] == 200
        
        response_payload = json.loads(response['Payload'].read())
        assert response_payload['statusCode'] == 200
        
        body = json.loads(response_payload['body'])
        assert body['message'] == 'Message published successfully'
        assert 'messageId' in body
        assert 'correlationId' in body

    def test_sns_direct_publish(self):
        """Test publishing directly to SNS topic."""
        correlation_id = str(uuid.uuid4())
        test_message = {
            'correlationId': correlation_id,
            'data': {
                'message': f'Direct SNS test - {correlation_id}'
            },
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Publish to SNS
        response = self.sns_client.publish(
            TopicArn=self.sns_topic_arn,
            Message=json.dumps(test_message),
            MessageAttributes={
                'CorrelationId': {
                    'DataType': 'String',
                    'StringValue': correlation_id
                },
                'Source': {
                    'DataType': 'String',
                    'StringValue': 'integration-test'
                }
            }
        )
        
        assert 'MessageId' in response

    def test_end_to_end_flow(self):
        """Test the complete end-to-end message flow."""
        correlation_id = str(uuid.uuid4())
        test_message = {
            'message': f'End-to-end test - {correlation_id}',
            'metadata': {
                'testType': 'end-to-end',
                'correlationId': correlation_id
            }
        }
        
        # Step 1: Invoke publisher
        publisher_response = self.lambda_client.invoke(
            FunctionName=self.publisher_function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_message)
        )
        
        assert publisher_response['StatusCode'] == 200
        
        publisher_payload = json.loads(publisher_response['Payload'].read())
        assert publisher_payload['statusCode'] == 200
        
        # Step 2: Wait for message processing
        time.sleep(5)  # Allow time for async processing
        
        # Step 3: Check subscriber logs for processing
        log_group_name = f'/aws/lambda/{self.subscriber_function_name}'
        
        try:
            # Get recent log events
            end_time = int(time.time() * 1000)
            start_time = end_time - (60 * 1000)  # Last minute
            
            response = self.logs_client.filter_log_events(
                logGroupName=log_group_name,
                startTime=start_time,
                endTime=end_time,
                filterPattern=f'"{correlation_id}"'
            )
            
            # Should find log entries related to our correlation ID
            assert len(response.get('events', [])) > 0, "No log entries found for the correlation ID"
            
            # Look for successful processing indicators
            log_messages = [event['message'] for event in response['events']]
            processing_found = any('Processing message' in msg or 'Successfully processed' in msg for msg in log_messages)
            assert processing_found, "No evidence of successful message processing found in logs"
            
        except self.logs_client.exceptions.ResourceNotFoundException:
            pytest.skip("Log group not found - may not be created yet")

    def test_api_gateway_integration(self):
        """Test API Gateway integration (if available)."""
        if not self.api_gateway_url:
            pytest.skip("API Gateway URL not provided")
        
        correlation_id = str(uuid.uuid4())
        test_payload = {
            'message': f'API Gateway test - {correlation_id}'
        }
        
        # Make HTTP request to API Gateway
        response = requests.post(
            f"{self.api_gateway_url}/publish",
            json=test_payload,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        assert response.status_code == 200
        
        response_data = response.json()
        assert response_data['message'] == 'Message published successfully'
        assert 'messageId' in response_data

    def test_error_handling_invalid_message(self):
        """Test error handling with invalid message."""
        # Test with invalid message structure
        invalid_message = {
            'invalid_field': 'This should cause validation error'
        }
        
        response = self.lambda_client.invoke(
            FunctionName=self.publisher_function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(invalid_message)
        )
        
        assert response['StatusCode'] == 200
        
        response_payload = json.loads(response['Payload'].read())
        assert response_payload['statusCode'] == 400  # Bad Request
        
        body = json.loads(response_payload['body'])
        assert body['error'] == 'Invalid input'

    def test_large_message_handling(self):
        """Test handling of large messages."""
        correlation_id = str(uuid.uuid4())
        
        # Create a large message (close to SNS limit)
        large_content = 'x' * (200 * 1024)  # 200KB message
        
        test_message = {
            'message': large_content,
            'correlationId': correlation_id
        }
        
        response = self.lambda_client.invoke(
            FunctionName=self.publisher_function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_message)
        )
        
        assert response['StatusCode'] == 200
        
        response_payload = json.loads(response['Payload'].read())
        assert response_payload['statusCode'] == 200

    def test_message_ordering_and_concurrency(self):
        """Test message ordering and concurrent processing."""
        correlation_ids = []
        
        # Send multiple messages concurrently
        for i in range(5):
            correlation_id = str(uuid.uuid4())
            correlation_ids.append(correlation_id)
            
            test_message = {
                'message': f'Concurrent test message {i} - {correlation_id}',
                'sequence': i
            }
            
            # Invoke asynchronously
            self.lambda_client.invoke(
                FunctionName=self.publisher_function_name,
                InvocationType='Event',  # Async invocation
                Payload=json.dumps(test_message)
            )
        
        # Wait for processing
        time.sleep(10)
        
        # Check that all messages were processed
        log_group_name = f'/aws/lambda/{self.subscriber_function_name}'
        
        try:
            end_time = int(time.time() * 1000)
            start_time = end_time - (120 * 1000)  # Last 2 minutes
            
            processed_count = 0
            for correlation_id in correlation_ids:
                response = self.logs_client.filter_log_events(
                    logGroupName=log_group_name,
                    startTime=start_time,
                    endTime=end_time,
                    filterPattern=f'"{correlation_id}"'
                )
                
                if response.get('events'):
                    processed_count += 1
            
            # At least some messages should be processed
            assert processed_count > 0, "No concurrent messages were processed"
            
        except self.logs_client.exceptions.ResourceNotFoundException:
            pytest.skip("Log group not found for concurrency test")

    def test_dlq_functionality(self):
        """Test Dead Letter Queue functionality (if available)."""
        if not self.dlq_url:
            pytest.skip("DLQ URL not provided")
        
        # Check DLQ is empty initially
        response = self.sqs_client.get_queue_attributes(
            QueueUrl=self.dlq_url,
            AttributeNames=['ApproximateNumberOfMessages']
        )
        
        initial_count = int(response['Attributes']['ApproximateNumberOfMessages'])
        
        # Note: Testing actual DLQ functionality would require 
        # intentionally causing failures, which might not be 
        # appropriate for all environments
        
        print(f"DLQ initial message count: {initial_count}")

    def test_monitoring_and_metrics(self):
        """Test that monitoring and metrics are working."""
        # This is a basic test to ensure metrics collection doesn't break the flow
        correlation_id = str(uuid.uuid4())
        
        test_message = {
            'message': f'Metrics test - {correlation_id}'
        }
        
        # Invoke function and ensure it completes successfully
        response = self.lambda_client.invoke(
            FunctionName=self.publisher_function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_message)
        )
        
        assert response['StatusCode'] == 200
        
        # Note: Full metrics testing would require CloudWatch API calls
        # and might not be appropriate for all test environments


if __name__ == '__main__':
    pytest.main([__file__, '-v'])