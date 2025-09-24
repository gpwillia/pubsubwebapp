terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-lambda-pubsub-sns"
      Environment = var.environment
      ManagedBy   = "terraform"
      CreatedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for consistent naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  
  # Lambda function names
  publisher_function_name  = "${local.name_prefix}-publisher"
  subscriber_function_name = "${local.name_prefix}-subscriber"
  
  # SNS topic name
  sns_topic_name = "${local.name_prefix}-topic"
}

# Create Lambda deployment packages
data "archive_file" "publisher_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/publisher"
  output_path = "${path.module}/../lambda-packages/publisher.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

data "archive_file" "subscriber_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/subscriber"
  output_path = "${path.module}/../lambda-packages/subscriber.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

# Create DynamoDB table for processing results (optional)
resource "aws_dynamodb_table" "processing_results" {
  count = var.enable_audit_trail ? 1 : 0
  
  name           = "${local.name_prefix}-processing-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "messageId"
  stream_enabled = false

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "correlationId"
    type = "S"
  }

  global_secondary_index {
    name     = "CorrelationIdIndex"
    hash_key = "correlationId"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-processing-results"
    Description = "Store processing results for audit trail"
  })
}

# Create SQS Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = "${local.name_prefix}-dlq"

  message_retention_seconds = var.dlq_retention_seconds
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-dlq"
    Description = "Dead letter queue for failed message processing"
  })
}

resource "aws_sqs_queue_policy" "dlq_policy" {
  queue_url = aws_sqs_queue.dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}