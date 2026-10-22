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

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the Kubernetes cluster"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "service_accounts" {
  description = "Map of service accounts to create with federated credentials"
  type = map(object({
    namespace        = string
    name             = string
    description      = string
    azure_role_ids   = list(string)  # Azure role assignment IDs
    aws_policy_arns  = list(string)  # AWS policy ARNs
    gcp_roles        = list(string)  # GCP roles
  }))
  default = {}
}