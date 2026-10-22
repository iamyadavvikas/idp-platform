output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = module.kubernetes_impl.cluster_id
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.kubernetes_impl.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes cluster"
  value       = module.kubernetes_impl.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "CA certificate of the Kubernetes cluster"
  value       = module.kubernetes_impl.cluster_ca_certificate
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity/IRSA"
  value       = module.kubernetes_impl.oidc_issuer_url
}

output "kubeconfig" {
  description = "Kubeconfig for the cluster"
  value       = module.kubernetes_impl.kubeconfig
  sensitive   = true
}

output "resource_group_name" {
  description = "Resource group name (Azure) or equivalent"
  value       = module.kubernetes_impl.resource_group_name
}