output "service_account_client_ids" {
  description = "Map of service account names to client IDs (Azure) or role ARNs (AWS)"
  value       = module.identity_impl.service_account_client_ids
}