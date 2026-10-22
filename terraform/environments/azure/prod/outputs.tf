output "cluster_name" {
  description = "AKS cluster name"
  value       = module.kubernetes.cluster_name
}

output "cluster_endpoint" {
  description = "AKS cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "AKS cluster CA certificate"
  value       = module.kubernetes.cluster_ca_certificate
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.kubernetes.oidc_issuer_url
}

output "vnet_id" {
  description = "VNet ID"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "system_subnet_ids" {
  description = "System subnet IDs"
  value       = module.networking.system_subnet_ids
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = module.secrets.keyvault_uri
}

output "keyvault_id" {
  description = "Key Vault ID"
  value       = module.secrets.keyvault_id
}

output "identity_client_ids" {
  description = "Workload Identity client IDs"
  value       = module.identity.service_account_client_ids
}

output "public_dns_zone_id" {
  description = "Public DNS zone ID"
  value       = module.dns.public_zone_id
}

output "private_dns_zone_id" {
  description = "Private DNS zone ID"
  value       = module.dns.private_zone_id
}

output "aks_private_dns_zone_id" {
  description = "AKS private DNS zone ID"
  value       = module.dns.aks_private_dns_zone_id
}