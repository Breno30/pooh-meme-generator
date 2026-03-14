provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "cname_app" {
  zone_id = var.cloudflare_zone_id
  name    = "meme"
  type    = "CNAME"
  content = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
  ttl     = 3600
  proxied = true
}