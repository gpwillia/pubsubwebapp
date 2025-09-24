# API Gateway for HTTP trigger (optional)
resource "aws_api_gateway_rest_api" "main" {
  count = var.create_api_gateway ? 1 : 0
  
  name        = "${local.name_prefix}-api"
  description = "API Gateway for Publisher Lambda function"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-api"
    Description = "API Gateway for Publisher Lambda function"
  })
}

resource "aws_api_gateway_resource" "publish" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  parent_id   = aws_api_gateway_rest_api.main[0].root_resource_id
  path_part   = "publish"
}

resource "aws_api_gateway_method" "publish_post" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id   = aws_api_gateway_rest_api.main[0].id
  resource_id   = aws_api_gateway_resource.publish[0].id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.main[0].id
  
  request_models = {
    "application/json" = aws_api_gateway_model.publish_request[0].name
  }
}

resource "aws_api_gateway_method" "publish_options" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id   = aws_api_gateway_rest_api.main[0].id
  resource_id   = aws_api_gateway_resource.publish[0].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "publisher_lambda" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  resource_id = aws_api_gateway_resource.publish[0].id
  http_method = aws_api_gateway_method.publish_post[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.publisher.invoke_arn
}

resource "aws_api_gateway_integration" "publish_options" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  resource_id = aws_api_gateway_resource.publish[0].id
  http_method = aws_api_gateway_method.publish_options[0].http_method

  type = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "publish_post" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  resource_id = aws_api_gateway_resource.publish[0].id
  http_method = aws_api_gateway_method.publish_post[0].http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "publish_options" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  resource_id = aws_api_gateway_resource.publish[0].id
  http_method = aws_api_gateway_method.publish_options[0].http_method
  status_code = "200"


}

resource "aws_api_gateway_integration_response" "publisher_lambda" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  resource_id = aws_api_gateway_resource.publish[0].id
  http_method = aws_api_gateway_method.publish_post[0].http_method
  status_code = aws_api_gateway_method_response.publish_post[0].status_code



  depends_on = [
    aws_api_gateway_integration.publisher_lambda
  ]
}

resource "aws_api_gateway_integration_response" "publish_options" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  resource_id = aws_api_gateway_resource.publish[0].id
  http_method = aws_api_gateway_method.publish_options[0].http_method
  status_code = aws_api_gateway_method_response.publish_options[0].status_code



  depends_on = [
    aws_api_gateway_integration.publish_options
  ]
}

resource "aws_api_gateway_request_validator" "main" {
  count = var.create_api_gateway ? 1 : 0
  
  name                        = "${local.name_prefix}-request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main[0].id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_model" "publish_request" {
  count = var.create_api_gateway ? 1 : 0
  
  rest_api_id  = aws_api_gateway_rest_api.main[0].id
  name         = "PublishRequest"
  content_type = "application/json"

  schema = jsonencode({
    type = "object"
    required = ["message"]
    properties = {
      message = {
        type = "string"
        minLength = 1
      }
      metadata = {
        type = "object"
        properties = {
          source = { type = "string" }
          priority = { type = "string" }
        }
      }
    }
  })
}

resource "aws_api_gateway_deployment" "main" {
  count = var.create_api_gateway ? 1 : 0
  
  depends_on = [
    aws_api_gateway_integration.publisher_lambda,
    aws_api_gateway_integration.publish_options
  ]

  rest_api_id = aws_api_gateway_rest_api.main[0].id
  stage_name  = var.environment

  variables = {
    deployed_at = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "api_gateway_invoke_publisher" {
  count = var.create_api_gateway ? 1 : 0
  
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.publisher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main[0].execution_arn}/*/*"
  qualifier     = aws_lambda_alias.publisher_live.name
}