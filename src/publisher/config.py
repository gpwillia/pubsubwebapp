"""Configuration settings for the Publisher Lambda function."""

import os

class Config:
    """Configuration constants and environment-based settings."""
    
    # Message size limits
    MAX_MESSAGE_SIZE = 256 * 1024  # 256KB (SNS limit)
    
    # Retry configuration
    MAX_RETRIES = int(os.environ.get('MAX_RETRIES', '3'))
    
    # Timeout configuration
    TIMEOUT_SECONDS = int(os.environ.get('TIMEOUT_SECONDS', '30'))
    
    # Environment settings
    ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
    AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
    
    # SNS configuration
    SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
    
    # Logging configuration
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    
    # CloudWatch metrics configuration
    METRICS_NAMESPACE = f"AWS/Lambda/PubSub/{ENVIRONMENT}"
    
    @classmethod
    def validate_required_env_vars(cls):
        """Validate that required environment variables are set."""
        required_vars = ['SNS_TOPIC_ARN']
        missing_vars = [var for var in required_vars if not os.environ.get(var)]
        
        if missing_vars:
            raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
    
    @classmethod
    def get_all_settings(cls):
        """Return all configuration settings as a dictionary."""
        return {
            'MAX_MESSAGE_SIZE': cls.MAX_MESSAGE_SIZE,
            'MAX_RETRIES': cls.MAX_RETRIES,
            'TIMEOUT_SECONDS': cls.TIMEOUT_SECONDS,
            'ENVIRONMENT': cls.ENVIRONMENT,
            'AWS_REGION': cls.AWS_REGION,
            'SNS_TOPIC_ARN': cls.SNS_TOPIC_ARN,
            'LOG_LEVEL': cls.LOG_LEVEL,
            'METRICS_NAMESPACE': cls.METRICS_NAMESPACE
        }