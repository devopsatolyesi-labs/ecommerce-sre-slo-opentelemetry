# ==============================================================================
# Cloudflare DNS & SSL/TLS Automation Module
# Provides automatic HTTPS, CDN CNAME records, and DDoS protection
# ==============================================================================

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.35.0"
    }
  }
}

# 1. Fetch Zone Data if zone_id is provided
data "cloudflare_zone" "this" {
  count   = var.enable_cloudflare && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
}

locals {
  zone_name   = length(data.cloudflare_zone.this) > 0 ? data.cloudflare_zone.this[0].name : var.domain_name
  target_host = var.alb_dns_name != "" ? var.alb_dns_name : "placeholder.amazonaws.com"
}

# 2. CNAME Record for OpenTelemetry Astronomy Shop Storefront
resource "cloudflare_record" "astronomy_shop" {
  count           = var.enable_cloudflare && var.cloudflare_zone_id != "" && var.alb_dns_name != "" ? 1 : 0
  zone_id         = var.cloudflare_zone_id
  name            = var.subdomain_prefix != "" ? var.subdomain_prefix : "astronomy"
  value           = local.target_host
  type            = "CNAME"
  proxied         = false
  ttl             = 60
  allow_overwrite = true
  comment         = "Managed by Terraform - OpenTelemetry Astronomy Shop Storefront (DNS-only for Let's Encrypt)"
}

# 3. CNAME Record for Grafana SRE & SLO Dashboard
resource "cloudflare_record" "grafana" {
  count           = var.enable_cloudflare && var.cloudflare_zone_id != "" && var.alb_dns_name != "" ? 1 : 0
  zone_id         = var.cloudflare_zone_id
  name            = var.subdomain_prefix != "" ? "grafana-${var.subdomain_prefix}" : "grafana"
  value           = local.target_host
  type            = "CNAME"
  proxied         = false
  ttl             = 60
  allow_overwrite = true
  comment         = "Managed by Terraform - Grafana SRE SLO & Observability Dashboard (DNS-only for Let's Encrypt)"
}

# 4. Optional CNAME Record for SonarQube Code Quality Server
resource "cloudflare_record" "sonarqube" {
  count           = var.enable_cloudflare && var.cloudflare_zone_id != "" && var.alb_dns_name != "" ? 1 : 0
  zone_id         = var.cloudflare_zone_id
  name            = var.subdomain_prefix != "" ? "sonar-${var.subdomain_prefix}" : "sonar"
  value           = local.target_host
  type            = "CNAME"
  proxied         = false
  ttl             = 60
  allow_overwrite = true
  comment         = "Managed by Terraform - SonarQube Code Quality & Security Platform (DNS-only for Let's Encrypt)"
}

