"""Unit tests for the Subscriber Lambda function."""

import json
import pytest
import unittest.mock
from unittest.mock import Mock, patch, MagicMock
from moto import mock_dynamodb, mock_cloudwatch
import boto3

# Import the lambda function
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'subscriber'))

import lambda_function
from lambda_function import MessageProcessingError


class TestSubscriberLambda:
    """Test cases for the Subscriber Lambda function."""

    def setup_method(self):
        """Set up test fixtures."""
        self.context = Mock()
        self.context.aws_request_id = 'test-request-id'
        self.context.function_name = 'test-subscriber'
        self.context.function_version = '1'
        self.context.memory_limit_in_mb = 512

    def create_sns_record(self, message_data, message_id='test-message-id'):
        """Helper to create SNS record structure."""
        return {
            'EventSource': 'aws:sns',
            'EventVersion': '1.0',
            'EventSubscriptionArn': 'arn:aws:sns:us-east-1:123456789012:test-topic:test-subscription',
            'Sns': {
                'Type': 'Notification',
                'MessageId': message_id,
                'TopicArn': 'arn:aws:sns:us-east-1:123456789012:test-topic',
                'Subject': 'Test Subject',
                'Message': json.dumps(message_data),
                'Timestamp': '2025-01-01T00:00:00.000Z',
                'SignatureVersion': '1',
                'Signature': 'test-signature',
                'SigningCertURL': 'https://sns.us-east-1.amazonaws.com/test.pem',
                'UnsubscribeURL': 'https://sns.us-east-1.amazonaws.com/test-unsubscribe',
                'MessageAttributes': {
                    'CorrelationId': {
                        'Type': 'String',
                        'Value': 'test-correlation-id'
                    },
                    'Source': {
                        'Type': 'String',
                        'Value': 'publisher-lambda'
                    }
                }
            }
        }

    def test_extract_correlation_id_from_attributes(self):
        """Test extracting correlation ID from message attributes."""
        message_attributes = {
            'CorrelationId': {'Value': 'test-correlation-id'}
        }
        parsed_message = {}
        
        result = lambda_function.extract_correlation_id(message_attributes, parsed_message)
        
        assert result == 'test-correlation-id'

    def test_extract_correlation_id_from_message(self):
        """Test extracting correlation ID from message body."""
        message_attributes = {}
        parsed_message = {'correlationId': 'message-correlation-id'}
        
        result = lambda_function.extract_correlation_id(message_attributes, parsed_message)
        
        assert result == 'message-correlation-id'

    def test_extract_correlation_id_generate_new(self):
        """Test generating new correlation ID when not found."""
        message_attributes = {}
        parsed_message = {}
        
        result = lambda_function.extract_correlation_id(message_attributes, parsed_message)
        
        assert len(result) == 36  # UUID format

    def test_extract_source_from_attributes(self):
        """Test extracting source from message attributes."""
        message_attributes = {
            'Source': {'Value': 'test-source'}
        }
        parsed_message = {}
        
        result = lambda_function.extract_source(message_attributes, parsed_message)
        
        assert result == 'test-source'

    def test_extract_source_from_message(self):
        """Test extracting source from message body."""
        message_attributes = {}
        parsed_message = {'source': 'message-source'}
        
        result = lambda_function.extract_source(message_attributes, parsed_message)
        
        assert result == 'message-source'

    def test_extract_source_unknown(self):
        """Test default source when not found."""
        message_attributes = {}
        parsed_message = {}
        
        result = lambda_function.extract_source(message_attributes, parsed_message)
        
        assert result == 'unknown'

    def test_validate_message_structure_valid(self):
        """Test validation with valid message structure."""
        message = {
            'data': {'message': 'test message'}
        }
        
        # Should not raise an exception
        lambda_function.validate_message_structure(message, 'test-id')

    def test_validate_message_structure_not_dict(self):
        """Test validation with non-dict message."""
        message = "not a dict"
        
        with pytest.raises(MessageProcessingError, match='must be a JSON object'):
            lambda_function.validate_message_structure(message, 'test-id')

    def test_validate_message_structure_missing_data(self):
        """Test validation with missing required fields."""
        message = {
            'metadata': 'some metadata'
        }
        
        with pytest.raises(MessageProcessingError, match='missing required field: data'):
            lambda_function.validate_message_structure(message, 'test-id')

    def test_process_text_message(self):
        """Test processing text message."""
        text_content = "Hello world test message"
        correlation_id = "test-id"
        
        result = lambda_function.process_text_message(text_content, correlation_id)
        
        assert result['type'] == 'text'
        assert result['wordCount'] == 4
        assert result['charCount'] == 24
        assert result['processed'] is True

    def test_process_order_message(self):
        """Test processing order message."""
        order_data = {
            'id': 'order-123',
            'total': 99.99
        }
        correlation_id = "test-id"
        
        result = lambda_function.process_order_message(order_data, correlation_id)
        
        assert result['type'] == 'order'
        assert result['orderId'] == 'order-123'
        assert result['totalAmount'] == 99.99
        assert result['processed'] is True

    def test_process_event_message(self):
        """Test processing event message."""
        event_data = {
            'type': 'user-signup',
            'timestamp': '2025-01-01T00:00:00Z'
        }
        correlation_id = "test-id"
        
        result = lambda_function.process_event_message(event_data, correlation_id)
        
        assert result['type'] == 'event'
        assert result['eventType'] == 'user-signup'
        assert result['eventTimestamp'] == '2025-01-01T00:00:00Z'
        assert result['processed'] is True

    def test_process_generic_message(self):
        """Test processing generic message."""
        data = {'some': 'data'}
        correlation_id = "test-id"
        
        result = lambda_function.process_generic_message(data, correlation_id)
        
        assert result['type'] == 'generic'
        assert result['dataType'] == 'dict'
        assert result['processed'] is True

    def test_process_message_content_text(self):
        """Test processing message content with text data."""
        message = {
            'data': {
                'message': 'test text message'
            }
        }
        
        result = lambda_function.process_message_content(message, 'test-id', 'msg-id', self.context)
        
        assert result['type'] == 'text'
        assert result['processed'] is True
        assert 'details' in result

    def test_process_message_content_order(self):
        """Test processing message content with order data."""
        message = {
            'data': {
                'order': {
                    'id': 'order-123',
                    'total': 150.00
                }
            }
        }
        
        result = lambda_function.process_message_content(message, 'test-id', 'msg-id', self.context)
        
        assert result['type'] == 'order'
        assert result['processed'] is True
        assert result['details']['orderId'] == 'order-123'

    def test_process_message_content_generic(self):
        """Test processing message content with generic data."""
        message = {
            'data': {
                'custom': 'data'
            }
        }
        
        result = lambda_function.process_message_content(message, 'test-id', 'msg-id', self.context)
        
        assert result['type'] == 'generic'
        assert result['processed'] is True

    def test_process_sns_record_success(self):
        """Test successful processing of SNS record."""
        message_data = {
            'data': {'message': 'test message'}
        }
        record = self.create_sns_record(message_data)
        
        result = lambda_function.process_sns_record(record, self.context)
        
        assert result['status'] == 'success'
        assert result['messageId'] == 'test-message-id'
        assert result['correlationId'] == 'test-correlation-id'
        assert result['source'] == 'publisher-lambda'

    def test_process_sns_record_invalid_json(self):
        """Test processing SNS record with invalid JSON."""
        record = {
            'Sns': {
                'MessageId': 'test-id',
                'Message': 'invalid json',
                'MessageAttributes': {}
            }
        }
        
        with pytest.raises(MessageProcessingError, match='Invalid JSON'):
            lambda_function.process_sns_record(record, self.context)

    def test_process_sns_record_validation_error(self):
        """Test processing SNS record that fails validation."""
        message_data = {
            'invalid': 'structure'  # Missing required 'data' field
        }
        record = self.create_sns_record(message_data)
        
        with pytest.raises(MessageProcessingError, match='missing required field'):
            lambda_function.process_sns_record(record, self.context)

    @mock_dynamodb
    @patch.dict(os.environ, {'PROCESSING_RESULTS_TABLE': 'test-table'})
    def test_store_processing_result(self):
        """Test storing processing result in DynamoDB."""
        # Create mock DynamoDB table
        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        table = dynamodb.create_table(
            TableName='test-table',
            KeySchema=[
                {'AttributeName': 'messageId', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'messageId', 'AttributeType': 'S'}
            ],
            BillingMode='PAY_PER_REQUEST'
        )
        
        # Mock the dynamodb resource in lambda_function
        with patch.object(lambda_function, 'dynamodb', dynamodb):
            lambda_function.store_processing_result(
                'test-message-id',
                'test-correlation-id',
                {'data': 'test'},
                {'processed': True},
                self.context
            )
            
            # Verify item was stored
            response = table.get_item(Key={'messageId': 'test-message-id'})
            assert 'Item' in response
            assert response['Item']['correlationId'] == 'test-correlation-id'

    @patch('lambda_function.store_processing_result')
    @patch('lambda_function.record_metrics')
    def test_lambda_handler_success(self, mock_record_metrics, mock_store):
        """Test successful lambda handler execution."""
        message_data = {
            'data': {'message': 'test message'}
        }
        
        event = {
            'Records': [self.create_sns_record(message_data)]
        }
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 200
        assert result['successfulRecords'] == 1
        assert result['failedRecords'] == 0
        assert len(result['results']) == 1
        assert result['results'][0]['status'] == 'success'

    @patch('lambda_function.record_metrics')
    def test_lambda_handler_processing_error(self, mock_record_metrics):
        """Test lambda handler with processing error."""
        # Create record with invalid message structure
        message_data = {'invalid': 'structure'}
        
        event = {
            'Records': [self.create_sns_record(message_data)]
        }
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 207  # Partial success
        assert result['successfulRecords'] == 0
        assert result['failedRecords'] == 1
        assert result['results'][0]['status'] == 'failed'

    @patch('lambda_function.process_sns_record')
    @patch('lambda_function.record_metrics')
    def test_lambda_handler_unexpected_error(self, mock_record_metrics, mock_process):
        """Test lambda handler with unexpected error."""
        mock_process.side_effect = Exception('Unexpected error')
        
        message_data = {'data': {'message': 'test'}}
        event = {
            'Records': [self.create_sns_record(message_data)]
        }
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 207
        assert result['failedRecords'] == 1
        assert result['results'][0]['status'] == 'error'

    @patch('lambda_function.cloudwatch')
    def test_record_metrics(self, mock_cloudwatch):
        """Test metrics recording."""
        from datetime import datetime
        
        start_time = datetime.utcnow()
        
        with patch.dict(os.environ, {'ENVIRONMENT': 'test'}):
            lambda_function.record_metrics(5, 2, start_time, self.context)
            
            mock_cloudwatch.put_metric_data.assert_called_once()
            call_args = mock_cloudwatch.put_metric_data.call_args
            assert call_args[1]['Namespace'] == 'AWS/Lambda/PubSub/test'
            assert len(call_args[1]['MetricData']) == 3  # Success, Failed, Latency metrics

    def test_custom_exception(self):
        """Test custom exception class."""
        error = MessageProcessingError('processing failed')
        assert str(error) == 'processing failed'


if __name__ == '__main__':
    pytest.main([__file__])