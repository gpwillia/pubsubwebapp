# SNS Topic
output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.main.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.main.name
}

# Publisher Lambda
output "publisher_lambda_function_arn" {
  description = "ARN of the publisher Lambda function"
  value       = aws_lambda_function.publisher.arn
}

output "publisher_lambda_function_name" {
  description = "Name of the publisher Lambda function"
  value       = aws_lambda_function.publisher.function_name
}

output "publisher_lambda_invoke_arn" {
  description = "Invoke ARN of the publisher Lambda function"
  value       = aws_lambda_function.publisher.invoke_arn
}

# Subscriber Lambda
output "subscriber_lambda_function_arn" {
  description = "ARN of the subscriber Lambda function"
  value       = aws_lambda_function.subscriber.arn
}

output "subscriber_lambda_function_name" {
  description = "Name of the subscriber Lambda function"
  value       = aws_lambda_function.subscriber.function_name
}

# IAM Roles
output "publisher_lambda_role_arn" {
  description = "ARN of the publisher Lambda execution role"
  value       = aws_iam_role.publisher_lambda_role.arn
}

output "subscriber_lambda_role_arn" {
  description = "ARN of the subscriber Lambda execution role"
  value       = aws_iam_role.subscriber_lambda_role.arn
}

# Dead Letter Queue
output "dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

# DynamoDB Table (if enabled)
output "processing_results_table_name" {
  description = "Name of the processing results DynamoDB table"
  value       = var.enable_audit_trail ? aws_dynamodb_table.processing_results[0].name : null
}

output "processing_results_table_arn" {
  description = "ARN of the processing results DynamoDB table"
  value       = var.enable_audit_trail ? aws_dynamodb_table.processing_results[0].arn : null
}

# CloudWatch Log Groups
output "publisher_log_group_name" {
  description = "Name of the publisher Lambda log group"
  value       = aws_cloudwatch_log_group.publisher_logs.name
}

output "subscriber_log_group_name" {
  description = "Name of the subscriber Lambda log group"
  value       = aws_cloudwatch_log_group.subscriber_logs.name
}

# API Gateway (if using API Gateway trigger for publisher)
output "api_gateway_url" {
  description = "URL of the API Gateway (if created)"
  value       = var.create_api_gateway ? aws_api_gateway_deployment.main[0].invoke_url : null
}

# Environment information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Resource naming
output "resource_name_prefix" {
  description = "Prefix used for resource naming"
  value       = local.name_prefix
}

# Deployment information
output "terraform_workspace" {
  description = "Terraform workspace"
  value       = terraform.workspace
}

# Testing endpoints (for integration tests)
output "test_endpoints" {
  description = "Endpoints for testing the deployment"
  value = {
    publisher_function_name  = aws_lambda_function.publisher.function_name
    subscriber_function_name = aws_lambda_function.subscriber.function_name
    sns_topic_arn           = aws_sns_topic.main.arn
    dlq_url                 = aws_sqs_queue.dlq.url
    api_gateway_url         = var.create_api_gateway ? aws_api_gateway_deployment.main[0].invoke_url : null
  }
}

# Monitoring endpoints
output "monitoring_resources" {
  description = "CloudWatch monitoring resources"
  value = var.enable_monitoring ? {
    dashboard_name = aws_cloudwatch_dashboard.main[0].dashboard_name
    alarm_names = [
      for alarm in aws_cloudwatch_metric_alarm.lambda_errors : alarm.alarm_name
    ]
  } : null
}

# Cost optimization information
output "cost_optimization_info" {
  description = "Information about cost optimization settings"
  value = {
    lambda_architecture              = var.lambda_architecture
    reserved_concurrent_executions  = var.reserved_concurrent_executions
    log_retention_days              = var.log_retention_in_days
    dlq_retention_days              = var.dlq_retention_seconds / 86400
  }
}