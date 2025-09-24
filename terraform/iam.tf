# Publisher Lambda IAM Role
resource "aws_iam_role" "publisher_lambda_role" {
  name = "${local.name_prefix}-publisher-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-publisher-lambda-role"
    Description = "IAM role for Publisher Lambda function"
  })
}

# Subscriber Lambda IAM Role
resource "aws_iam_role" "subscriber_lambda_role" {
  name = "${local.name_prefix}-subscriber-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-subscriber-lambda-role"
    Description = "IAM role for Subscriber Lambda function"
  })
}

# Basic Lambda execution policy attachment for Publisher
resource "aws_iam_role_policy_attachment" "publisher_basic_execution" {
  role       = aws_iam_role.publisher_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Basic Lambda execution policy attachment for Subscriber
resource "aws_iam_role_policy_attachment" "subscriber_basic_execution" {
  role       = aws_iam_role.subscriber_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy (if VPC is configured)
resource "aws_iam_role_policy_attachment" "publisher_vpc_execution" {
  count      = var.vpc_id != "" ? 1 : 0
  role       = aws_iam_role.publisher_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "subscriber_vpc_execution" {
  count      = var.vpc_id != "" ? 1 : 0
  role       = aws_iam_role.subscriber_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing policy (if enabled)
resource "aws_iam_role_policy_attachment" "publisher_xray" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.publisher_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "subscriber_xray" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.subscriber_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Publisher Lambda custom policy
resource "aws_iam_role_policy" "publisher_lambda_policy" {
  name = "${local.name_prefix}-publisher-lambda-policy"
  role = aws_iam_role.publisher_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AWS/Lambda/PubSub/${var.environment}"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.publisher_logs.arn}:*"
      }
    ]
  })
}

# Subscriber Lambda custom policy
resource "aws_iam_role_policy" "subscriber_lambda_policy" {
  name = "${local.name_prefix}-subscriber-lambda-policy"
  role = aws_iam_role.subscriber_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AWS/Lambda/PubSub/${var.environment}"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.subscriber_logs.arn}:*"
      }
    ]
  })
}

# Additional policy for DynamoDB access (if audit trail is enabled)
resource "aws_iam_role_policy" "subscriber_dynamodb_policy" {
  count = var.enable_audit_trail ? 1 : 0
  name  = "${local.name_prefix}-subscriber-dynamodb-policy"
  role  = aws_iam_role.subscriber_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.processing_results[0].arn,
          "${aws_dynamodb_table.processing_results[0].arn}/index/*"
        ]
      }
    ]
  })
}

# KMS policy for encryption (if KMS key is provided)
resource "aws_iam_role_policy" "publisher_kms_policy" {
  count = var.kms_key_id != "" ? 1 : 0
  name  = "${local.name_prefix}-publisher-kms-policy"
  role  = aws_iam_role.publisher_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "subscriber_kms_policy" {
  count = var.kms_key_id != "" ? 1 : 0
  name  = "${local.name_prefix}-subscriber-kms-policy"
  role  = aws_iam_role.subscriber_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
      }
    ]
  })
}