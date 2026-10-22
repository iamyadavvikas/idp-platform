variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "keyvault_name" {
  description = "Not used for AWS"
  type        = string
  default     = ""
}

variable "secrets_manager_name" {
  description = "Name of the Secrets Manager"
  type        = string
  default     = ""
}

variable "secret_manager_project_id" {
  description = "Not used for AWS"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "Not used for AWS"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Not used for AWS"
  type        = list(string)
  default     = []
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  type        = string
}