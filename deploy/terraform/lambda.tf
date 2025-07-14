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
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
}

resource "aws_lambda_function_url" "lambda_function_url" {
  function_name = aws_lambda_function.service_lambda_function.function_name
  authorization_type = "NONE" 
}