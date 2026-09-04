# ==============================================================================
# AWS ACM Certificate Management Module
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
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


