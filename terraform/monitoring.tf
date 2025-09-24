# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_monitoring ? 1 : 0
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = templatefile("${path.module}/../monitoring/dashboards/pubsub-dashboard.json", {
    aws_region               = var.aws_region
    environment             = var.environment
    publisher_function_name = aws_lambda_function.publisher.function_name
    subscriber_function_name = aws_lambda_function.subscriber.function_name
    sns_topic_name          = aws_sns_topic.main.name
    dlq_name               = aws_sqs_queue.dlq.name
  })
}

# SNS Topic for Monitoring Alerts
resource "aws_sns_topic" "monitoring_alerts" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${local.name_prefix}-monitoring-alerts"

  tags = local.common_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "publisher_error_rate" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-publisher-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors publisher lambda error count"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.publisher.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "subscriber_error_rate" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-subscriber-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors subscriber lambda error count"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.subscriber.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "publisher_duration" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-publisher-high-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "This metric monitors publisher lambda duration"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.publisher.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "subscriber_duration" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-subscriber-high-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "This metric monitors subscriber lambda duration"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.subscriber.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "publisher_throttles" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-publisher-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors publisher lambda throttles"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.publisher.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "subscriber_throttles" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-subscriber-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors subscriber lambda throttles"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.subscriber.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sns_delivery_failures" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-sns-delivery-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors SNS delivery failures"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors messages in DLQ"
  alarm_actions       = [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts[0].arn]

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = local.common_tags
}

# Legacy dashboard widget definition (keeping for backward compatibility)
resource "aws_cloudwatch_dashboard" "legacy" {
  count          = 0 # Disabled in favor of template-based dashboard
  dashboard_name = "${local.name_prefix}-legacy-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.publisher.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Publisher Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.subscriber.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Subscriber Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SNS", "NumberOfMessagesPublished", "TopicName", aws_sns_topic.main.name],
            [".", "NumberOfNotificationsDelivered", ".", "."],
            [".", "NumberOfNotificationsFailed", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "SNS Topic Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.dlq.name],
            [".", "NumberOfMessagesReceived", ".", "."],
            [".", "ApproximateNumberOfVisibleMessages", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Dead Letter Queue Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda/PubSub/${var.environment}", "MessagePublishCount", "FunctionName", aws_lambda_function.publisher.function_name, "MetricType", "Success"],
            [".", ".", ".", ".", ".", "ValidationError"],
            [".", ".", ".", ".", ".", "SNSError"],
            [".", "MessagesProcessed", "FunctionName", aws_lambda_function.subscriber.function_name, "Status", "Success"],
            [".", ".", ".", ".", ".", "Failed"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Custom Business Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.enable_monitoring ? {
    publisher  = aws_lambda_function.publisher.function_name
    subscriber = aws_lambda_function.subscriber.function_name
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors ${each.key} lambda errors"
  alarm_actions       = var.sns_alarm_topic_arn != "" ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    FunctionName = each.value
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-errors-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.enable_monitoring ? {
    publisher  = aws_lambda_function.publisher.function_name
    subscriber = aws_lambda_function.subscriber.function_name
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.lambda_timeout * 1000 * 0.8  # 80% of timeout
  alarm_description   = "This metric monitors ${each.key} lambda duration"
  alarm_actions       = var.sns_alarm_topic_arn != "" ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    FunctionName = each.value
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-duration-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "sns_failed_notifications" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-sns-failed-notifications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors SNS failed notifications"
  alarm_actions       = var.sns_alarm_topic_arn != "" ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sns-failed-notifications-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors DLQ message count"
  alarm_actions       = var.sns_alarm_topic_arn != "" ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dlq-messages-alarm"
  })
}

# Custom metric filters for application logs
resource "aws_cloudwatch_log_metric_filter" "publisher_errors" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "${local.name_prefix}-publisher-errors"
  log_group_name = aws_cloudwatch_log_group.publisher_logs.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "PublisherErrors"
    namespace = "AWS/Lambda/PubSub/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "subscriber_errors" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "${local.name_prefix}-subscriber-errors"
  log_group_name = aws_cloudwatch_log_group.subscriber_logs.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "SubscriberErrors"
    namespace = "AWS/Lambda/PubSub/${var.environment}"
    value     = "1"
  }
}

# Log insights queries (saved queries for troubleshooting)
resource "aws_cloudwatch_query_definition" "publisher_performance" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${local.name_prefix}-publisher-performance"

  log_group_names = [
    aws_cloudwatch_log_group.publisher_logs.name
  ]

  query_string = <<EOF
fields @timestamp, @message, @requestId
| filter @message like /Processing request/
| parse @message "Processing request *" as correlationId
| stats count() by bin(5m)
EOF
}

resource "aws_cloudwatch_query_definition" "subscriber_errors" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${local.name_prefix}-subscriber-error-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.subscriber_logs.name
  ]

  query_string = <<EOF
fields @timestamp, @message, @requestId
| filter @level = "ERROR"
| stats count() by @message
| sort count desc
EOF
}