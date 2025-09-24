"""Unit tests for the Publisher Lambda function."""

import json
import pytest
import unittest.mock
from unittest.mock import Mock, patch, MagicMock
from moto import mock_sns, mock_cloudwatch
import boto3

# Import the lambda function
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'publisher'))

import lambda_function
from lambda_function import ValidationError, SNSPublishError


class TestPublisherLambda:
    """Test cases for the Publisher Lambda function."""

    def setup_method(self):
        """Set up test fixtures."""
        self.context = Mock()
        self.context.aws_request_id = 'test-request-id'
        self.context.function_name = 'test-publisher'
        self.context.function_version = '1'
        self.context.memory_limit_in_mb = 256

    def test_validate_input_valid_message(self):
        """Test validation with valid message."""
        event = {
            'body': json.dumps({
                'message': 'Hello, World!'
            })
        }
        
        result = lambda_function.validate_input(event)
        
        assert result['message'] == 'Hello, World!'

    def test_validate_input_direct_message(self):
        """Test validation with direct message (not API Gateway format)."""
        event = {
            'message': 'Direct message'
        }
        
        result = lambda_function.validate_input(event)
        
        assert result['message'] == 'Direct message'

    def test_validate_input_missing_message(self):
        """Test validation with missing message field."""
        event = {
            'body': json.dumps({
                'data': 'some data'
            })
        }
        
        with pytest.raises(ValidationError, match='Message field is required'):
            lambda_function.validate_input(event)

    def test_validate_input_empty_message(self):
        """Test validation with empty message."""
        event = {
            'body': json.dumps({
                'message': ''
            })
        }
        
        with pytest.raises(ValidationError, match='Message cannot be empty'):
            lambda_function.validate_input(event)

    def test_validate_input_invalid_json(self):
        """Test validation with invalid JSON."""
        event = {
            'body': 'invalid json'
        }
        
        with pytest.raises(ValidationError, match='Invalid JSON in request body'):
            lambda_function.validate_input(event)

    def test_validate_input_message_too_large(self):
        """Test validation with message exceeding size limit."""
        large_message = 'x' * (256 * 1024 + 1)  # Exceed 256KB limit
        event = {
            'body': json.dumps({
                'message': large_message
            })
        }
        
        with pytest.raises(ValidationError, match='Message size .* exceeds limit'):
            lambda_function.validate_input(event)

    def test_prepare_message(self):
        """Test message preparation with metadata."""
        message_data = {'message': 'test message'}
        correlation_id = 'test-correlation-id'
        
        result = lambda_function.prepare_message(message_data, correlation_id, self.context)
        
        assert result['correlationId'] == correlation_id
        assert result['source'] == 'publisher-lambda'
        assert result['requestId'] == 'test-request-id'
        assert result['data'] == message_data
        assert 'timestamp' in result
        assert 'metadata' in result
        assert result['metadata']['functionName'] == 'test-publisher'

    @mock_sns
    def test_publish_message_success(self):
        """Test successful message publishing to SNS."""
        # Set up mocked SNS
        sns_client = boto3.client('sns', region_name='us-east-1')
        topic_response = sns_client.create_topic(Name='test-topic')
        topic_arn = topic_response['TopicArn']
        
        # Mock environment variable
        with patch.dict(os.environ, {'SNS_TOPIC_ARN': topic_arn}):
            message = {
                'correlationId': 'test-id',
                'data': {'message': 'test'}
            }
            
            # Mock the sns_client in lambda_function
            with patch.object(lambda_function, 'sns_client', sns_client):
                result = lambda_function.publish_message(message, 'test-id')
                
                assert 'MessageId' in result

    def test_publish_message_no_topic_arn(self):
        """Test publishing without SNS_TOPIC_ARN environment variable."""
        with patch.dict(os.environ, {}, clear=True):
            message = {'test': 'message'}
            
            with pytest.raises(SNSPublishError, match='SNS_TOPIC_ARN environment variable not set'):
                lambda_function.publish_message(message, 'test-id')

    @patch('lambda_function.sns_client')
    def test_publish_message_sns_error(self, mock_sns_client):
        """Test handling of SNS publishing errors."""
        # Mock SNS client to raise an error
        mock_sns_client.publish.side_effect = Exception('SNS error')
        
        with patch.dict(os.environ, {'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:test'}):
            message = {'test': 'message'}
            
            with pytest.raises(SNSPublishError):
                lambda_function.publish_message(message, 'test-id')

    @patch('lambda_function.cloudwatch')
    def test_record_metrics(self, mock_cloudwatch):
        """Test metrics recording."""
        from datetime import datetime
        
        start_time = datetime.utcnow()
        
        with patch.dict(os.environ, {'ENVIRONMENT': 'test'}):
            lambda_function.record_metrics('Success', 'test-id', start_time)
            
            mock_cloudwatch.put_metric_data.assert_called_once()
            call_args = mock_cloudwatch.put_metric_data.call_args
            assert call_args[1]['Namespace'] == 'AWS/Lambda/PubSub/test'
            assert len(call_args[1]['MetricData']) == 2  # Count and Latency metrics

    @patch('lambda_function.publish_message')
    @patch('lambda_function.validate_input')
    @patch('lambda_function.record_metrics')
    def test_lambda_handler_success(self, mock_record_metrics, mock_validate, mock_publish):
        """Test successful lambda handler execution."""
        # Setup mocks
        mock_validate.return_value = {'message': 'test message'}
        mock_publish.return_value = {'MessageId': 'test-message-id'}
        
        event = {
            'body': json.dumps({'message': 'test message'})
        }
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'Message published successfully'
        assert body['messageId'] == 'test-message-id'
        assert 'correlationId' in body
        
        mock_record_metrics.assert_called_once()

    @patch('lambda_function.validate_input')
    @patch('lambda_function.record_metrics')
    def test_lambda_handler_validation_error(self, mock_record_metrics, mock_validate):
        """Test lambda handler with validation error."""
        mock_validate.side_effect = ValidationError('Invalid input')
        
        event = {'body': 'invalid'}
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert body['error'] == 'Invalid input'
        
        mock_record_metrics.assert_called_once_with('ValidationError', unittest.mock.ANY, unittest.mock.ANY)

    @patch('lambda_function.publish_message')
    @patch('lambda_function.validate_input')
    @patch('lambda_function.record_metrics')
    def test_lambda_handler_sns_error(self, mock_record_metrics, mock_validate, mock_publish):
        """Test lambda handler with SNS publishing error."""
        mock_validate.return_value = {'message': 'test'}
        mock_publish.side_effect = SNSPublishError('SNS failed')
        
        event = {'body': json.dumps({'message': 'test'})}
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 500
        body = json.loads(result['body'])
        assert body['error'] == 'Failed to publish message'
        
        mock_record_metrics.assert_called_once_with('SNSError', unittest.mock.ANY, unittest.mock.ANY)

    @patch('lambda_function.validate_input')
    @patch('lambda_function.record_metrics')
    def test_lambda_handler_unexpected_error(self, mock_record_metrics, mock_validate):
        """Test lambda handler with unexpected error."""
        mock_validate.side_effect = Exception('Unexpected error')
        
        event = {'body': json.dumps({'message': 'test'})}
        
        result = lambda_function.lambda_handler(event, self.context)
        
        assert result['statusCode'] == 500
        body = json.loads(result['body'])
        assert body['error'] == 'Internal server error'
        
        mock_record_metrics.assert_called_once_with('UnexpectedError', unittest.mock.ANY, unittest.mock.ANY)

    def test_custom_exceptions(self):
        """Test custom exception classes."""
        validation_error = ValidationError('validation failed')
        assert str(validation_error) == 'validation failed'
        
        sns_error = SNSPublishError('sns failed')
        assert str(sns_error) == 'sns failed'


if __name__ == '__main__':
    pytest.main([__file__])