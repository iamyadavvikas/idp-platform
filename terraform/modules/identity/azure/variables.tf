variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster"
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
    namespace                = string
    name                     = string
    description              = string
    azure_identity_id        = string
    azure_identity_client_id = string
    azure_identity_object_id = string
    azure_role_scope         = string
    azure_role_name          = string
    aws_policy_arns          = list(string)
    gcp_roles                = list(string)
  }))
  default = {}
}