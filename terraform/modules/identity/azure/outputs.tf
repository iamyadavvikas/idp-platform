output "service_account_client_ids" {
  description = "Map of service account names to client IDs"
  value       = { for k, v in var.service_accounts : k => v.azure_identity_client_id }
}