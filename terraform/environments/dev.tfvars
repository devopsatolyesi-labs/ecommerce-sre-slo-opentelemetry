# ==============================================================================
# Development Environment Variables (AWS Dev Profile - Optimized Footprint)
# ==============================================================================
aws_region          = "us-east-1"
environment         = "dev"
cluster_name        = "astronomy-shop"
k8s_version         = "1.32"
vpc_cidr            = "10.10.0.0/16"
node_instance_types = ["t3.medium"]
desired_nodes       = 3
max_nodes           = 4
min_nodes           = 1
capacity_type       = "ON_DEMAND"
enable_ecs          = false
enable_cloudflare   = true
domain_name         = "devopsatolyesi.com"

