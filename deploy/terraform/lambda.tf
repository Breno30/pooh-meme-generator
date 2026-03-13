data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../../src/lambda/pooh_meme_generator/app.py"
  output_path = "${path.module}/temp/lambda.zip"
}

resource "aws_lambda_function" "service_lambda_function" {
  depends_on       = [data.archive_file.lambda]
  filename         = "temp/lambda.zip"
  function_name    = local.lambda_function_name
  source_code_hash = data.archive_file.lambda.output_base64sha256
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  environment {
    variables = {
      APP_REGION     = "${var.aws_region}"
      TABLE_NAME     = local.dynamodb_table_name
      MODEL_ID       = var.model_id
      PROVIDER       = var.model_provider
      OPENAI_API_KEY = var.openai_api_key
    }
  }

  layers = [
    aws_lambda_layer_version.requests_layer.arn
  ]

}

resource "aws_lambda_layer_version" "requests_layer" {
  layer_name               = "requests"
  compatible_runtimes      = ["python3.12", "python3.11", "python3.10"]
  filename                 = "src/layers/requests.zip"
  description              = "Requests library for Python Lambda"
  compatible_architectures = ["x86_64", "arm64"]
}

resource "aws_lambda_function_url" "lambda_function_url" {
  function_name      = aws_lambda_function.service_lambda_function.function_name
  authorization_type = "NONE"
}