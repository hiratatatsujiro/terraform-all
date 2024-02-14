resource "aws_secretsmanager_secret" "cloudfront_secret" {
  description = "Secret for CloudFront"
  name        = "hirata-automation-cloudfront-secret"
}

resource "random_string" "random" {
  length  = 64
  special = false
  upper   = true
  numeric  = true
}


resource "aws_secretsmanager_secret_version" "cloudfront_secret_version" {
  secret_id     = aws_secretsmanager_secret.cloudfront_secret.id
  secret_string = random_string.random.result
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "hirata_automation_cloudfront_access_logs" {
  bucket = "hirata-automation-cloudfront-accesslogs-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name = "hirata_automation_cloudfront_accesslogs_${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_ownership_controls" "ownership_controls" {
  bucket = aws_s3_bucket.hirata_automation_cloudfront_access_logs.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hirata_automation_cloudfront_access_logs_sse" {
  bucket = aws_s3_bucket.hirata_automation_cloudfront_access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "hirata_automation_cloudfront_access_logs_lifecycle" {
  bucket = aws_s3_bucket.hirata_automation_cloudfront_access_logs.id
  rule {
    id     = "log"
    status = "Enabled"
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket" "hirata_automation_cloudfront_redirections" {
  bucket = "hirata-automation-cloudfront-redirections"
  tags = {
    Name = "hirata-automation-cloudfront-redirections"
  }
}

resource "aws_s3_bucket_website_configuration" "hirata_automation_cloudfront_redirections_website" {
  bucket = aws_s3_bucket.hirata_automation_cloudfront_redirections.bucket
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
  routing_rules = jsonencode([{
    Condition = {
      KeyPrefixEquals = "favicon.ico"
    },
    Redirect = {
      HostName = "cdn.hirata-automation.net"
      HttpRedirectCode = "302"
      Protocol = "https"
      ReplaceKeyWith = "images/favicon.ico"
    }
  }, {
    Redirect = {
      HostName = "cdn.hirata-automation.net"
      HttpRedirectCode = "301"
      Protocol = "https"
      ReplaceKeyPrefixWith = "users"
    }
  }])
}


resource "aws_s3_bucket_server_side_encryption_configuration" "hirata_automation_cloudfront_redirections" {
  bucket = aws_s3_bucket.hirata_automation_cloudfront_redirections.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "hirata_automation_cloudfront_redirections_lifecycle" {
  bucket = aws_s3_bucket.hirata_automation_cloudfront_redirections.id
  rule {
    id     = "log"
    status = "Enabled"
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket" "hirata_automation_static_contents" {
  bucket = "hirata-automation-cloudfront-staticcontents"
  tags = {
    Name = "hirata-automation-cloudfront-staticcontents"
  }
}

resource "aws_s3_bucket_policy" "hirata_automation_static_contents_policy" {
  bucket = aws_s3_bucket.hirata_automation_static_contents.id
  policy = file("${path.module}/policy.json")
  
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hirata_automation_cloudfront_static_contents" {
  bucket = aws_s3_bucket.hirata_automation_static_contents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "hirata_automation_oac" {
  name                              = "hirata-automation-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "hirata_automation_distribution" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "hirata-automation-cloudfront"
  http_version    = "http2and3"
  price_class     = "PriceClass_200"

  aliases = ["cdn.hirata-automation.net"]
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    target_origin_id       = var.elb_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # Managed-AllViewer
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
  }

  # ELB Origin
  origin {
    domain_name = var.elb_dns_name
    origin_id   = var.elb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "x-via-cloudfront"
      value = random_string.random.result
    }
  }

  # S3 Static Contents Origin
  origin {
    domain_name = aws_s3_bucket.hirata_automation_static_contents.bucket_regional_domain_name
    origin_id   = var.s3_staticcontents_origin_id

    # s3_origin_config {
    #   origin_access_identity = ""
    # }
    origin_access_control_id = aws_cloudfront_origin_access_control.hirata_automation_oac.id
  }

  # S3 Website Redirections Origin
  origin {
    domain_name = "${aws_s3_bucket.hirata_automation_cloudfront_redirections.bucket}.s3-website-${var.aws_region}.amazonaws.com"
    origin_id   = var.s3_website_origin_id

    custom_origin_config {
      http_port              = 80
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      https_port             = 443
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    include_cookies = true
    bucket          = aws_s3_bucket.hirata_automation_cloudfront_access_logs.bucket_domain_name
    prefix          = "logs/"
  }

  # S3 Website: Redirections
  ordered_cache_behavior {
    path_pattern     = "/favicon.ico"
    target_origin_id = var.s3_website_origin_id

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    compress            = true
    cache_policy_id     = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
  }

  ordered_cache_behavior {
    path_pattern     = "/"
    target_origin_id = var.s3_website_origin_id

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    compress            = true
    cache_policy_id     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
  }

  # S3: Static Contents
  ordered_cache_behavior {
    path_pattern     = "/css/*"
    target_origin_id = var.s3_staticcontents_origin_id

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    compress            = true
    cache_policy_id     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
  }

  ordered_cache_behavior {
    path_pattern     = "/images/*"
    target_origin_id = var.s3_staticcontents_origin_id

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    compress            = true
    cache_policy_id     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
  }

  ordered_cache_behavior {
    path_pattern     = "/js/*"
    target_origin_id = var.s3_staticcontents_origin_id

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    compress            = true
    cache_policy_id     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
  }

  tags = {
    Name        = "hirata-automation-cloudfront"
  }
}

resource "aws_route53_record" "ipv4" {
  zone_id = var.zone_id
  name    = "cdn.hirata-automation.net"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.hirata_automation_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.hirata_automation_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ipv6" {
  zone_id = var.zone_id
  name    = "cdn.hirata-automation.net"
  type    = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.hirata_automation_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.hirata_automation_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_lb_listener_rule" "cloudfront_rule" {
  listener_arn = var.elb_listner_https_arn
  priority     = 200

  condition {
    http_header {
      http_header_name = "x-via-cloudfront"
      values           = [aws_secretsmanager_secret_version.cloudfront_secret_version.secret_string]
    }
  }

  action {
    type = "fixed-response"
    fixed_response {
      status_code = "404"
      content_type = "text/html"
      message_body = <<-EOT
        <html>
        <head>
        <title>404 Not Found</title>
        <link rel="icon" href="/images/favicon.ico">
        </head>
        <body>
        <center><h1>昨日探し当てた場所に今日もジャンプしてみるけどなぜか404 Not Found</h1></center>
        <center><h1>今日は404 Not Found</h1></center>
        <center><h1>Mr.Children 404 Not Found</h1></center>
        </body>
        </html>
      EOT
    }
  }
}