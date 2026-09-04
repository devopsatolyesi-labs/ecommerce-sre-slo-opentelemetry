variable "cluster_name" {
  type        = string
  description = "Base cluster name"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes control plane version"
  default     = "1.32"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EKS control plane"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EKS managed node group"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for EKS managed node group"
  default     = ["t3.medium"]
}

variable "desired_nodes" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_nodes" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "min_nodes" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "capacity_type" {
  type        = string
  description = "Capacity type for worker nodes (ON_DEMAND or SPOT)"
  default     = "ON_DEMAND"
}
