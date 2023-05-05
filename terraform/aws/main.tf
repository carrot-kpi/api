terraform {
  required_providers {
    aws = {
      version = ">= 4.65"
    }
  }
}

resource "aws_s3_bucket" "main" {
  bucket = "carrot-kpi-main"
}

locals {
  hero_video_name = "hero-video.webm"
  hero_video_path = "${path.module}/resources/${local.hero_video_name}"
}

resource "aws_s3_bucket_object" "hero_video" {
  bucket = aws_s3_bucket.main.id
  key    = local.hero_video_name
  source = local.hero_video_path
  etag   = filemd5(local.hero_video_path)
}

resource "aws_cloudfront_origin_access_identity" "main" {
}

data "aws_iam_policy_document" "main" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.main.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.main.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.main.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.main.json
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_s3_bucket.main.bucket_domain_name
    origin_id   = aws_s3_bucket.main.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  default_root_object = local.hero_video_name

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.main.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }
}
