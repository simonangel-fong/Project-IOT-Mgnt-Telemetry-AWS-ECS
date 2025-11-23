# variable
locals {
  aws_cf_origin_api = "${var.project}-${var.env}-origin-api"
  aws_cf_origin_web = "${var.project}-${var.env}-origin-web"
}

# acm certificate
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1" # Required for CloudFront ACM
}

data "aws_acm_certificate" "cf_certificate" {
  domain      = "*.${var.dns_domain}"
  provider    = aws.us_east_1
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
# ###############################
# CloudFront
# ###############################
resource "aws_cloudfront_distribution" "ecs_cdn" {

  # S3 static website origin
  origin {
    origin_id = local.aws_cf_origin_web

    domain_name = aws_s3_bucket_website_configuration.website_config.website_endpoint

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # S3 website is HTTP-only
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API origin
  origin {
    origin_id   = local.aws_cf_origin_api
    domain_name = aws_alb.lb.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # or "https-only" if your ALB listens on 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior-> web
  default_cache_behavior {
    target_origin_id       = local.aws_cf_origin_web
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    compress        = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # /api/* -> ALB
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = local.aws_cf_origin_api
    viewer_protocol_policy = "redirect-to-https"

    # API can use all methods
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    compress        = true

    # API usually should NOT be cached (or only very short TTLs)
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    forwarded_values {
      query_string = true

      # Whitelist headers that matter for CORS / auth / your API key
      headers = [
        "Origin",
        "Access-Control-Request-Method",
        "Access-Control-Request-Headers",
        "x-api-key",
      ]

      cookies {
        forward = "none"
      }
    }
  }

  enabled             = true
  aliases             = [local.dns_name] # iot-dev.arguswatcher.net
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cf_certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.project}-${var.env}-cloudfront"
  }
}
