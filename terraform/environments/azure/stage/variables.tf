variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stage"
}

variable "region" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name prefix"
  type        = string
  default     = "idp"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "VNet CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for DNS"
  type        = string
  default     = "idp.example.com"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Environment = "stage"
    Project     = "idp-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}