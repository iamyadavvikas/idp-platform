output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "cluster_ca_certificate" {
  description = "CA certificate of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_profile[0].issuer_url
}

output "kubeconfig" {
  description = "Kubeconfig for the cluster"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.aks.name
}

output "aks_identity_client_id" {
  description = "Client ID of the AKS user-assigned identity"
  value       = azurerm_user_assigned_identity.aks_identity.client_id
}

output "aks_identity_object_id" {
  description = "Object ID of the AKS user-assigned identity"
  value       = azurerm_user_assigned_identity.aks_identity.principal_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.this.id
}