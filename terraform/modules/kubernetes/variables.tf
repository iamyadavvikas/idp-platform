variable "cloud_provider" {
  description = "Cloud provider: aws, azure, gcp"
  type        = string
  validation {
    condition     = contains(["aws", "azure", "gcp"], var.cloud_provider)
    error_message = "cloud_provider must be aws, azure, or gcp."
  }
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "Cloud region"
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
  description = "ID of the VPC/VNet"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC/VNet"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of private subnets for worker nodes"
  type        = list(string)
}

variable "system_subnet_ids" {
  description = "IDs of system subnets for system node pool (Azure only)"
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
    vm_size             = string
    min_count           = number
    max_count           = number
    desired_count       = number
    enable_spot         = bool
    node_labels         = map(string)
    node_taints         = list(string)
    tags                = map(string)
  }))
  default = {}
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity / IRSA"
  type        = bool
  default     = true
}

variable "enable_cilium" {
  description = "Enable Cilium CNI"
  type        = bool
  default     = true
}