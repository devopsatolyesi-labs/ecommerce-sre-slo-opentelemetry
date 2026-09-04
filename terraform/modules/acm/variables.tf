variable "enable_acm_ssl" {
  description = "Flag to enable AWS ACM Certificate creation and management"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Domain name for ACM Certificate (e.g. devopsatolyesi.com)"
  type        = string
  default     = ""
}

variable "enable_cloudflare" {
  description = "Flag to enable automatic Cloudflare DNS record creation for validation"
  type        = bool
  default     = false
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for target domain"
  type        = string
  default     = ""
}
