"""Configuration settings for the Subscriber Lambda function."""

import os

class Config:
    """Configuration constants and environment-based settings."""
    
    # Message size limits
    MAX_MESSAGE_SIZE = 256 * 1024  # 256KB (SNS limit)
    
    # Processing configuration
    MAX_RETRIES = int(os.environ.get('MAX_RETRIES', '3'))
    
    # Timeout configuration
    TIMEOUT_SECONDS = int(os.environ.get('TIMEOUT_SECONDS', '30'))
    
    # Environment settings
    ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
    AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
    
    # DynamoDB configuration (for storing processing results)
    PROCESSING_RESULTS_TABLE = os.environ.get('PROCESSING_RESULTS_TABLE')
    RESULT_TTL_DAYS = int(os.environ.get('RESULT_TTL_DAYS', '7'))
    
    # Dead Letter Queue configuration
    DLQ_ARN = os.environ.get('DLQ_ARN')
    
    # Logging configuration
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    
    # CloudWatch metrics configuration
    METRICS_NAMESPACE = f"AWS/Lambda/PubSub/{ENVIRONMENT}"
    
    # Business logic configuration
    ENABLE_AUDIT_TRAIL = os.environ.get('ENABLE_AUDIT_TRAIL', 'true').lower() == 'true'
    ENABLE_DETAILED_LOGGING = os.environ.get('ENABLE_DETAILED_LOGGING', 'false').lower() == 'true'
    
    @classmethod
    def validate_optional_env_vars(cls):
        """Validate optional environment variables and log warnings if missing."""
        import logging
        logger = logging.getLogger()
        
        optional_vars = {
            'PROCESSING_RESULTS_TABLE': 'Audit trail storage will be disabled',
            'DLQ_ARN': 'Dead letter queue not configured'
        }
        
        for var, warning in optional_vars.items():
            if not os.environ.get(var):
                logger.warning(f"{var} not set: {warning}")
    
    @classmethod
    def get_all_settings(cls):
        """Return all configuration settings as a dictionary."""
        return {
            'MAX_MESSAGE_SIZE': cls.MAX_MESSAGE_SIZE,
            'MAX_RETRIES': cls.MAX_RETRIES,
            'TIMEOUT_SECONDS': cls.TIMEOUT_SECONDS,
            'ENVIRONMENT': cls.ENVIRONMENT,
            'AWS_REGION': cls.AWS_REGION,
            'PROCESSING_RESULTS_TABLE': cls.PROCESSING_RESULTS_TABLE,
            'RESULT_TTL_DAYS': cls.RESULT_TTL_DAYS,
            'DLQ_ARN': cls.DLQ_ARN,
            'LOG_LEVEL': cls.LOG_LEVEL,
            'METRICS_NAMESPACE': cls.METRICS_NAMESPACE,
            'ENABLE_AUDIT_TRAIL': cls.ENABLE_AUDIT_TRAIL,
            'ENABLE_DETAILED_LOGGING': cls.ENABLE_DETAILED_LOGGING
        }