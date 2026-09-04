variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the AWS EKS and ECS cluster"
  type        = string
  default     = "astronomy-shop"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "k8s_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.32"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "capacity_type" {
  description = "Capacity type for worker nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "enable_ecs" {
  description = "Whether to provision AWS ECS Fargate resources"
  type        = bool
  default     = false
}

# ==============================================================================
# AWS ACM SSL/TLS & Cloudflare Configuration
# ==============================================================================

variable "enable_acm_ssl" {
  description = "Flag to enable AWS ACM Certificate creation and management via Terraform"
  type        = bool
  default     = true
}

variable "enable_cloudflare" {
  description = "Flag to enable automated Cloudflare DNS records and SSL proxy"
  type        = bool
  default     = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone.DNS edit permissions"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for target domain"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name hosted on Cloudflare (e.g. devopsatolyesi.com)"
  type        = string
  default     = ""
}

variable "subdomain_prefix" {
  description = "Subdomain prefix for the deployment"
  type        = string
  default     = "astronomy"
}

variable "alb_dns_name" {
  description = "AWS Application Load Balancer DNS Hostname to map CNAME to"
  type        = string
  default     = ""
}

