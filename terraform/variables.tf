# Project configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-lambda-pubsub-sns"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Lambda configuration
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_architecture" {
  description = "Architecture for Lambda functions (x86_64 or arm64)"
  type        = string
  default     = "arm64"
  
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Architecture must be either x86_64 or arm64."
  }
}

variable "publisher_memory_size" {
  description = "Memory size for publisher Lambda function (MB)"
  type        = number
  default     = 256
  
  validation {
    condition     = var.publisher_memory_size >= 128 && var.publisher_memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "subscriber_memory_size" {
  description = "Memory size for subscriber Lambda function (MB)"
  type        = number
  default     = 512
  
  validation {
    condition     = var.subscriber_memory_size >= 128 && var.subscriber_memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (seconds)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

# Networking configuration (optional)
variable "vpc_id" {
  description = "VPC ID for Lambda functions (optional)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda functions (required if vpc_id is provided)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda functions (optional)"
  type        = list(string)
  default     = []
}

# SNS configuration
variable "sns_display_name" {
  description = "Display name for SNS topic"
  type        = string
  default     = "PubSub Topic"
}

variable "sns_delivery_policy" {
  description = "SNS delivery policy configuration"
  type = object({
    max_delay_target     = optional(number, 20)
    min_delay_target     = optional(number, 20)
    num_retries          = optional(number, 3)
    num_max_delay_retries = optional(number, 0)
    num_min_delay_retries = optional(number, 0)
    num_no_delay_retries  = optional(number, 0)
    backup_failure_retry_policy = optional(number, -1)
  })
  default = {}
}

# Monitoring configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch dashboards and alarms"
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention value."
  }
}

# Features configuration
variable "enable_audit_trail" {
  description = "Enable DynamoDB table for storing processing results"
  type        = bool
  default     = false
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda functions"
  type        = bool
  default     = true
}

# Dead Letter Queue configuration
variable "dlq_retention_seconds" {
  description = "Message retention time in DLQ (seconds)"
  type        = number
  default     = 1209600  # 14 days
  
  validation {
    condition     = var.dlq_retention_seconds >= 60 && var.dlq_retention_seconds <= 1209600
    error_message = "DLQ retention must be between 60 seconds and 14 days."
  }
}

# Lambda environment variables
variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "max_retries" {
  description = "Maximum number of retries for Lambda functions"
  type        = number
  default     = 3
  
  validation {
    condition     = var.max_retries >= 0 && var.max_retries <= 10
    error_message = "Max retries must be between 0 and 10."
  }
}

# Cost optimization
variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda functions (-1 for unreserved)"
  type        = number
  default     = -1
}

# KMS configuration
variable "kms_key_id" {
  description = "KMS key ID for encryption (optional - uses AWS managed key if not provided)"
  type        = string
  default     = ""
}

# Additional tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Monitoring alerts
variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "enable_dlq_alerts" {
  description = "Enable DLQ monitoring alerts"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

# API Gateway configuration
variable "create_api_gateway" {
  description = "Create API Gateway for HTTP trigger to publisher Lambda"
  type        = bool
  default     = false
}

# Lambda Layer configuration
variable "create_common_layer" {
  description = "Create common Lambda layer for shared dependencies"
  type        = bool
  default     = false
}