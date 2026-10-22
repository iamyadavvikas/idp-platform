variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the GKE cluster"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "service_accounts" {
  description = "Map of service accounts to create with Workload Identity"
  type = map(object({
    namespace       = string
    name            = string
    description     = string
    azure_role_ids  = list(string)
    aws_policy_arns = list(string)
    gcp_roles       = list(string)
  }))
  default = {}
}