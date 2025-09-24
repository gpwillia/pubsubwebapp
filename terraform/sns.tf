# SNS Topic
resource "aws_sns_topic" "main" {
  name         = local.sns_topic_name
  display_name = var.sns_display_name
  
  # KMS encryption (optional)
  kms_master_key_id = var.kms_key_id != "" ? "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null

  # Delivery policy for retry logic
  delivery_policy = jsonencode({
    "http" = {
      "defaultHealthyRetryPolicy" = {
        "minDelayTarget"     = var.sns_delivery_policy.min_delay_target
        "maxDelayTarget"     = var.sns_delivery_policy.max_delay_target
        "numRetries"         = var.sns_delivery_policy.num_retries
        "numMaxDelayRetries" = var.sns_delivery_policy.num_max_delay_retries
        "numMinDelayRetries" = var.sns_delivery_policy.num_min_delay_retries
        "numNoDelayRetries"  = var.sns_delivery_policy.num_no_delay_retries
        "backoffFunction"    = "linear"
      }
      "disableSubscriptionOverrides" = false
      "defaultThrottlePolicy" = {
        "maxReceivesPerSecond" = 1000
      }
    }
  })

  tags = merge(local.common_tags, {
    Name        = local.sns_topic_name
    Description = "SNS topic for Pub/Sub messaging"
  })
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "main" {
  arn = aws_sns_topic.main.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublisherLambdaPublish"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.publisher_lambda_role.arn
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.main.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowSubscriberLambdaReceive"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:Receive"
        ]
        Resource = aws_sns_topic.main.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# SNS Subscription - Lambda
resource "aws_sns_topic_subscription" "subscriber_lambda" {
  topic_arn              = aws_sns_topic.main.arn
  protocol               = "lambda"
  endpoint               = aws_lambda_function.subscriber.arn
  confirmation_timeout_in_minutes = 1
  
  # Subscription attributes
  filter_policy = jsonencode({
    "Environment" = [var.environment]
  })
  
  # Dead letter queue for failed deliveries
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
  })

  depends_on = [
    aws_lambda_permission.allow_sns_invoke_subscriber
  ]
}

# Lambda permission for SNS to invoke subscriber function
resource "aws_lambda_permission" "allow_sns_invoke_subscriber" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscriber.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
  qualifier     = aws_lambda_alias.subscriber_live.name
}

# Optional: SNS Subscription for DLQ monitoring
resource "aws_sns_topic_subscription" "dlq_alerts" {
  count     = var.enable_dlq_alerts ? 1 : 0
  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = var.alert_email

  filter_policy = jsonencode({
    "MessageType" = ["DLQ"]
  })
}