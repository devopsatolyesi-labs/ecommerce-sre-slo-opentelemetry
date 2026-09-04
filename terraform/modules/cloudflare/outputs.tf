output "astronomy_https_url" {
  description = "HTTPS URL for Astronomy Shop Storefront via Cloudflare"
  value       = var.enable_cloudflare && var.cloudflare_zone_id != "" ? "https://${var.subdomain_prefix}.${local.zone_name}" : ""
}

output "grafana_https_url" {
  description = "HTTPS URL for Grafana SRE Dashboard via Cloudflare"
  value       = var.enable_cloudflare && var.cloudflare_zone_id != "" ? "https://grafana-${var.subdomain_prefix}.${local.zone_name}" : ""
}

output "sonarqube_https_url" {
  description = "HTTPS URL for SonarQube Server via Cloudflare"
  value       = var.enable_cloudflare && var.cloudflare_zone_id != "" ? "https://sonar-${var.subdomain_prefix}.${local.zone_name}" : ""
}

output "cloudflare_enabled" {
  description = "Status of Cloudflare DNS automation"
  value       = var.enable_cloudflare
}
