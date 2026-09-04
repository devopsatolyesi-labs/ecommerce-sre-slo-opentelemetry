# ==============================================================================
# AWS ACM Certificate & Cloudflare Automated DNS Validation Module
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.35.0"
    }
  }
}

# 1. AWS ACM Certificate Request (Root + Wildcard SAN)
resource "aws_acm_certificate" "cert" {
  count             = var.enable_acm_ssl && var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.environment}-acm-cert"
    Environment = var.environment
  }
}

# 2. Automated Cloudflare DNS Validation Records (if Cloudflare enabled)
resource "cloudflare_record" "acm_validation" {
  for_each = var.enable_acm_ssl && var.enable_cloudflare && var.cloudflare_zone_id != "" && length(aws_acm_certificate.cert) > 0 ? {
    for dvo in distinct([
      for dvo in aws_acm_certificate.cert[0].domain_validation_options : {
        name   = trimsuffix(dvo.resource_record_name, ".")
        record = trimsuffix(dvo.resource_record_value, ".")
        type   = dvo.resource_record_type
      }
    ]) : dvo.name => dvo
  } : {}

  zone_id         = var.cloudflare_zone_id
  name            = each.value.name
  value           = each.value.record
  type            = each.value.type
  proxied         = false
  ttl             = 60
  allow_overwrite = true
  comment         = "AWS ACM DNS Validation"
}



# 3. ACM Certificate Validation Waiter
resource "aws_acm_certificate_validation" "cert_valid" {
  count                   = var.enable_acm_ssl && var.enable_cloudflare && length(aws_acm_certificate.cert) > 0 && length(cloudflare_record.acm_validation) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in cloudflare_record.acm_validation : record.hostname]
}

