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

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "keyvault_name" {
  description = "Name of the Key Vault (Azure)"
  type        = string
  default     = ""
}

variable "secrets_manager_name" {
  description = "Name of the Secrets Manager (AWS)"
  type        = string
  default     = ""
}

variable "secret_manager_project_id" {
  description = "Project ID for Secret Manager (GCP)"
  type        = string
  default     = ""
}