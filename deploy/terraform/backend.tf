terraform {
  backend "s3" {
    bucket = "terraform-state-pooh-meme-generator-prod"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
