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
  depends_on   = [aws_s3_bucket_ownership_controls.project_bucket_ownership]
  bucket       = aws_s3_bucket.project_bucket.id
  key          = "js/main.js"
  source       = "js/main.js"
  etag         = filemd5("js/main.js")
  content_type = "application/javascript"
  acl          = "public-read"
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