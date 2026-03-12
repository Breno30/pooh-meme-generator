variable "aws_region" {
  description = "The AWS region where resources will be deployed (e.g., 'us-east-1')."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A unique name for the project, used as a prefix for naming resources (e.g., 'my-app')."
  type        = string
  default     = "pooh-meme-generator"
}

variable "lambda_memory_size" {
  description = "The amount of memory (in MB) allocated to the Lambda function."
  type        = number
  default     = 1024 # Default to 1024 MB
}

variable "lambda_timeout" {
  description = "The maximum amount of time (in seconds) that the Lambda function can run."
  type        = number
  default     = 10 # Default to 10 seconds
}

variable "model_id" {
  description = "The ID of the model to use for generating memes (e.g., 'anthropic.claude-3-haiku-20240307-v1:0')."
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "model_provider" {
  description = "The provider to use for the model (e.g., 'bedrock, openai')."
  type        = string
  default     = "bedrock"
}