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