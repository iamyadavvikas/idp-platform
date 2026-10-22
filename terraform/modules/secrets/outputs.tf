output "keyvault_id" {
  description = "ID of the Key Vault / Secrets Manager"
  value       = module.secrets_impl.keyvault_id
}

output "keyvault_uri" {
  description = "URI of the Key Vault / Secrets Manager"
  value       = module.secrets_impl.keyvault_uri
}

output "identity_client_id" {
  description = "Client ID of the identity for workload identity/IRSA"
  value       = module.secrets_impl.identity_client_id
}

output "identity_object_id" {
  description = "Object ID of the identity"
  value       = module.secrets_impl.identity_object_id
}