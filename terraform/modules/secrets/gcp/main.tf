# GCP Secret Manager Module - Stub Implementation
# TODO: Implement full Secret Manager with Workload Identity

output "keyvault_id" {
  description = "ID of the Secret Manager"
  value       = "gcp-secret-manager-${var.environment}"
}

output "keyvault_uri" {
  description = "URI of the Secret Manager"
  value       = ""
}

output "identity_client_id" {
  description = "Client ID of the identity"
  value       = ""
}

output "identity_object_id" {
  description = "Object ID of the identity"
  value       = ""
}