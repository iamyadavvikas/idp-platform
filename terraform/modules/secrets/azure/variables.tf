variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "keyvault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = ""
}

variable "secrets_manager_name" {
  description = "Not used for Azure"
  type        = string
  default     = ""
}

variable "secret_manager_project_id" {
  description = "Not used for Azure"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VNet"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of private subnets"
  type        = list(string)
}