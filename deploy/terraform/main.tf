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

# Variables
variable "aws_region" {
  description = "A prefix to use for naming resources, like 'my-project'."
  type        = string
}

variable "project_name" {
  description = "A prefix to use for naming resources, like 'my-project'."
  type        = string
}

variable "lambda_memory_size" {
  description = "A prefix to use for naming resources, like 'my-project'."
  type        = number
}

variable "lambda_timeout" {
  description = "A prefix to use for naming resources, like 'my-project'."
  type        = number
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "PoohMeme"
      Environment = "Development"
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  project_hash_result    = random_string.project_hash.result
  dynamodb_table_name    = "${var.project_name}-${local.project_hash_result}"
  lambda_function_name   = "${var.project_name}-lambda-function-${local.project_hash_result}"
  iam_role_name          = "service-lambda-execution-role-${local.project_hash_result}"
  iam_policy_name        = "lambda-bedrock-invoke-policy-${local.project_hash_result}"
  s3_bucket_name         = "${var.project_name}-${local.project_hash_result}"
}

resource "random_string" "project_hash" {
  length           = 16
  special          = false
  upper            = false 
  numeric          = true
}

resource "aws_dynamodb_table" "project_table" {
  name         = local.dynamodb_table_name
  attribute {
    name = "input_text"
    type = "S"
  }
  hash_key     = "input_text"
  read_capacity  = 5
  write_capacity = 5
}

resource "aws_iam_role" "lambda_execution_role" {
  name = local.iam_role_name

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
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = local.iam_policy_name
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

# Archive lambda function code
resource "local_file" "lambda_code" {
  filename = "index.py"

  content = templatefile("../../src/lambda/index.py", {
    table_name = aws_dynamodb_table.project_table.name
  })
}

data "archive_file" "lambda" {
  depends_on  = [local_file.lambda_code]
  type        = "zip"
  source_file = "index.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "service_lambda_function" {
  depends_on = [data.archive_file.lambda]
  filename      = "lambda.zip"
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  memory_size   = 1024
  timeout       = 10
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
resource "aws_s3_bucket" "project_bucket" {
  bucket = local.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.project_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.project_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.public_access_block]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
          Sid = "PublicReadGetObject",
          Effect = "Allow",
          Principal = "*",
          Action = "s3:GetObject",
          Resource = "${aws_s3_bucket.project_bucket.arn}/*"
        }
    ]
  })
}

resource "aws_s3_bucket_ownership_controls" "project_bucket_ownership" {
  bucket = aws_s3_bucket.project_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_object" "object" {
  depends_on = [local_file.index_html, aws_s3_bucket_ownership_controls.project_bucket_ownership]
  bucket = aws_s3_bucket.project_bucket.id
  key    = "index.html"
  source = "index.html"
  etag = filemd5("../../src/app/index.html")
  content_type = "text/html"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "images" {
  for_each = {
    simple        = "../../src/app/simple.jpg"
    complex       = "../../src/app/complex.jpg"
    sophisticated = "../../src/app/sophisticated.jpg"
  }
  depends_on   = [local_file.index_html, aws_s3_bucket_ownership_controls.project_bucket_ownership]
  bucket       = aws_s3_bucket.project_bucket.id
  key          = "${each.key}.jpg"
  source       = each.value
  etag         = filemd5(each.value)
  content_type = "image/jpeg"
  acl          = "public-read"
}

resource "aws_s3_bucket_website_configuration" "project_website" {
  bucket = aws_s3_bucket.project_bucket.id

  index_document {
    suffix = "index.html"
  }

}

output "bucket_name" {
  value = aws_s3_bucket.project_bucket.id
  description = "The name of the S3 bucket hosting the static website."
}

output "lambda_function_url" {
  value = aws_lambda_function_url.lambda_function_url.function_url
  description = "The URL endpoint for the deployed Lambda function."
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.project_website.website_endpoint
  description = "The public URL of the static website hosted on S3."
}