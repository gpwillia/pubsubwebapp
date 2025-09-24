# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "publisher_logs" {
  name              = "/aws/lambda/${local.publisher_function_name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_id != "" ? "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-publisher-logs"
    Description = "CloudWatch logs for Publisher Lambda function"
  })
}

resource "aws_cloudwatch_log_group" "subscriber_logs" {
  name              = "/aws/lambda/${local.subscriber_function_name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_id != "" ? "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-subscriber-logs"
    Description = "CloudWatch logs for Subscriber Lambda function"
  })
}

# Publisher Lambda Function
resource "aws_lambda_function" "publisher" {
  depends_on = [
    aws_iam_role_policy_attachment.publisher_basic_execution,
    aws_cloudwatch_log_group.publisher_logs
  ]

  filename         = data.archive_file.publisher_zip.output_path
  function_name    = local.publisher_function_name
  role            = aws_iam_role.publisher_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.publisher_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.publisher_memory_size
  architectures   = [var.lambda_architecture]

  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      SNS_TOPIC_ARN        = aws_sns_topic.main.arn
      LOG_LEVEL            = var.log_level
      MAX_RETRIES          = var.max_retries
      TIMEOUT_SECONDS      = var.lambda_timeout
      AWS_REGION           = var.aws_region
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  tags = merge(local.common_tags, {
    Name        = local.publisher_function_name
    Description = "Lambda function for publishing messages to SNS"
  })
}

# Subscriber Lambda Function
resource "aws_lambda_function" "subscriber" {
  depends_on = [
    aws_iam_role_policy_attachment.subscriber_basic_execution,
    aws_cloudwatch_log_group.subscriber_logs
  ]

  filename         = data.archive_file.subscriber_zip.output_path
  function_name    = local.subscriber_function_name
  role            = aws_iam_role.subscriber_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.subscriber_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.subscriber_memory_size
  architectures   = [var.lambda_architecture]

  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = {
      ENVIRONMENT              = var.environment
      LOG_LEVEL               = var.log_level
      MAX_RETRIES             = var.max_retries
      TIMEOUT_SECONDS         = var.lambda_timeout
      AWS_REGION              = var.aws_region
      PROCESSING_RESULTS_TABLE = var.enable_audit_trail ? aws_dynamodb_table.processing_results[0].name : ""
      RESULT_TTL_DAYS         = "7"
      DLQ_ARN                 = aws_sqs_queue.dlq.arn
      ENABLE_AUDIT_TRAIL      = var.enable_audit_trail
      ENABLE_DETAILED_LOGGING = "false"
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tags = merge(local.common_tags, {
    Name        = local.subscriber_function_name
    Description = "Lambda function for processing SNS messages"
  })
}

# Lambda function versions (for blue/green deployments)
resource "aws_lambda_alias" "publisher_live" {
  name             = "live"
  description      = "Live alias for publisher function"
  function_name    = aws_lambda_function.publisher.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

resource "aws_lambda_alias" "subscriber_live" {
  name             = "live"
  description      = "Live alias for subscriber function"
  function_name    = aws_lambda_function.subscriber.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

# Lambda Layer for common dependencies (optional)
resource "aws_lambda_layer_version" "common_layer" {
  count = var.create_common_layer ? 1 : 0
  
  filename            = "${path.module}/../lambda-packages/common-layer.zip"
  layer_name          = "${local.name_prefix}-common-layer"
  compatible_runtimes = [var.lambda_runtime]
  compatible_architectures = [var.lambda_architecture]
  
  description = "Common dependencies layer for Lambda functions"
  
  lifecycle {
    create_before_destroy = true
  }
}