resource "aws_iam_role" "example" {
  name = "test_role"

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
    tag-key = "tag-value"
  }
}

resource "aws_api_gateway_rest_api" "api_gateway_example" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "example"
      version = "1.0"
    }
  })

  name = "example"

}

resource "aws_lambda_function" "example_function" {
  filename      = "lambda.zip"
  function_name = "example_function"
  role          = aws_iam_role.example.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
}

# -----------

resource "aws_api_gateway_resource" "example_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway_example.id
  parent_id   = aws_api_gateway_rest_api.api_gateway_example.root_resource_id
  path_part   = "your_path"  # e.g., "items" or "users"
}

resource "aws_api_gateway_method" "example_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway_example.id
  resource_id   = aws_api_gateway_resource.example_resource.id 
  http_method   = "POST"
  authorization = "NONE" # You can change this based on your authorization needs
}

resource "aws_api_gateway_integration" "lambda_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway_example.id
  resource_id             = aws_api_gateway_resource.example_resource.id 
  http_method             = aws_api_gateway_method.example_method.http_method 
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example_function.invoke_arn
}

