output "keyvault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.this.id
}

output "keyvault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}

output "identity_client_id" {
  description = "Client ID of the External Secrets identity"
  value       = azurerm_user_assigned_identity.external_secrets.client_id
}

output "identity_object_id" {
  description = "Object ID of the External Secrets identity"
  value       = azurerm_user_assigned_identity.external_secrets.principal_id
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.kv.name
}