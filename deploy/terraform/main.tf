terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "service-lambda-execution-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = "PoohMeme"
    Environment = "Development"
  }
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = "lambda-bedrock-invoke-policy"
  description = "Allow Lambda to invoke Bedrock foundation models and access DynamoDB"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "bedrock:InvokeModel",
        Resource = "arn:aws:bedrock:*:*:foundation-model/*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_bedrock_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}

resource "aws_api_gateway_rest_api" "service_api_gateway" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "PoohMemeAPI"
      version = "1.0"
    }
  })

  name        = "pooh-meme-api"
  description = "API Gateway for pooh meme generator"
}

# Archive lambda function code
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../../src/lambda/index.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "service_lambda_function" {
  filename      = "lambda.zip"
  function_name = "pooh-meme-lambda-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda.index.lambda_handler"
  runtime       = "python3.12"

  tags = {
    Project     = "PoohMeme"
    Environment = "Development"
  }
}

resource "aws_api_gateway_resource" "api_path_resource" {
  rest_api_id = aws_api_gateway_rest_api.service_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.service_api_gateway.root_resource_id
  path_part   = "generate"
}

resource "aws_api_gateway_method" "post_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.service_api_gateway.id
  resource_id   = aws_api_gateway_resource.api_path_resource.id
  http_method   = "POST"
  authorization = "NONE" # You can change this based on your authorization needs
}

resource "aws_api_gateway_integration" "lambda_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.service_api_gateway.id
  resource_id             = aws_api_gateway_resource.api_path_resource.id
  http_method             = aws_api_gateway_method.post_api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.service_lambda_function.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.service_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.service_api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_function_url" "lambda_function_url" {
  function_name = aws_lambda_function.service_lambda_function.function_name
  authorization_type = "NONE" 
}

# Rendered HTML file
resource "local_file" "index_html" {
  filename = "index.html"

  content = templatefile("../../src/app/index.html", {
    lambda_function_endpoint = aws_lambda_function_url.lambda_function_url.function_url
  })
}

# S3
resource "random_string" "bucket_name" {
  length           = 16
  special          = false
  upper            = false 
  numeric          = true
}

resource "aws_s3_bucket" "project_bucket" {
  bucket = "pooh-meme-${random_string.bucket_name.result}"
  region = "us-east-1"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.project_bucket.id
  key    = "index.html"
  source = "index.html"
  etag = filemd5("../../src/app/index.html")
}

output "bucket_name" {
  value = aws_s3_bucket.project_bucket.id
}

output "lambda_function_endpoint" {
  value = aws_api_gateway_integration.lambda_proxy_integration.rest_api_id
}

output "lambda_function_url" {
  value = aws_lambda_function_url.lambda_function_url.function_url
}