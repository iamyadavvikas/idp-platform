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

variable "domain_name" {
  description = "Domain name for DNS zone"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "create_public_zone" {
  description = "Create public DNS zone"
  type        = bool
  default     = true
}

variable "create_private_zone" {
  description = "Create private DNS zone"
  type        = bool
  default     = true
}