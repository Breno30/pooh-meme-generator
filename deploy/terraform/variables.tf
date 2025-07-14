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
