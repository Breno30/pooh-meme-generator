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
  lambda_function_name   = "lambda-function-${var.project_name}-${local.project_hash_result}"
  iam_role_name          = "lambda-execution-role-${var.project_name}-${local.project_hash_result}"
  iam_policy_name        = "lambda-bedrock-invoke-policy-${var.project_name}-${local.project_hash_result}"
  s3_bucket_name         = "${var.project_name}-${local.project_hash_result}"
}

resource "random_string" "project_hash" {
  length           = 16
  special          = false
  upper            = false 
  numeric          = true
}