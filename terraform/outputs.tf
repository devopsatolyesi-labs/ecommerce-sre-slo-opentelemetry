output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster Name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS Cluster API Endpoint"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public Subnet IDs"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private Subnet IDs"
}

output "region" {
  value       = var.aws_region
  description = "AWS Region deployed to"
}

output "environment" {
  value       = var.environment
  description = "Deployment environment"
}
