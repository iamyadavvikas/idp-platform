variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of private subnets for worker nodes"
  type        = list(string)
}

variable "system_subnet_ids" {
  description = "Not used for AWS"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "node_pools" {
  description = "Map of node pool configurations"
  type = map(object({
    instance_types      = list(string)
    min_size            = number
    max_size            = number
    desired_size        = number
    enable_spot         = bool
    capacity_type       = string
    node_labels         = map(string)
    node_taints         = list(string)
  }))
  default = {}
}

variable "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "enable_workload_identity" {
  description = "Enable IRSA"
  type        = bool
  default     = true
}

variable "enable_cilium" {
  description = "Enable Cilium CNI (not applicable for AWS VPC CNI)"
  type        = bool
  default     = false
}