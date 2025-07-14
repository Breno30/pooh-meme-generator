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
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.project_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_bedrock_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}