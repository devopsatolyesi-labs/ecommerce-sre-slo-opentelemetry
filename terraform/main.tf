# ==============================================================================
# Modular Multi-Environment Terraform Root
# Supports dev, staging, and production via -var-file and separate tfstates
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.35.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ecommerce-sre-slo-opentelemetry"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Atolyesi"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
}

# 1. Reusable VPC Module (Single NAT Gateway for optimized cost & limits)
module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
  environment  = var.environment
}

# 2. Reusable EKS Module
module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  environment        = var.environment
  k8s_version        = var.k8s_version
  subnet_ids         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  private_subnet_ids = module.vpc.private_subnets
  instance_types     = var.node_instance_types
  desired_nodes      = var.desired_nodes
  max_nodes          = var.max_nodes
  min_nodes          = var.min_nodes
  capacity_type      = var.capacity_type
}

# 3. Optional Hybrid ECS Fargate Module
module "ecs" {
  count        = var.enable_ecs ? 1 : 0
  source       = "./modules/ecs"
  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
}

# 4. Optional Cloudflare DNS & Automated SSL Module
module "cloudflare" {
  source               = "./modules/cloudflare"
  enable_cloudflare    = var.enable_cloudflare
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  domain_name          = var.domain_name
  subdomain_prefix     = var.subdomain_prefix
  alb_dns_name         = var.alb_dns_name
}
