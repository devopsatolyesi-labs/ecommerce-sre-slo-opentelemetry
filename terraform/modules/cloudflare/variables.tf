variable "enable_cloudflare" {
  type        = bool
  description = "Flag to enable or disable automatic Cloudflare DNS & SSL provisioning"
  default     = false
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token with Zone.DNS permissions"
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for target domain"
  default     = ""
}

variable "domain_name" {
  type        = string
  description = "Domain name hosted on Cloudflare (e.g. devopsatolyesi.com)"
  default     = ""
}

variable "subdomain_prefix" {
  type        = string
  description = "Subdomain prefix for the deployment (e.g. astronomy-dev)"
  default     = "astronomy"
}

variable "alb_dns_name" {
  type        = string
  description = "AWS Application Load Balancer DNS Hostname to point CNAME records to"
  default     = ""
}
