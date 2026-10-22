# GCP Kubernetes Module - Stub Implementation
# TODO: Implement full GKE with Workload Identity, Cilium, etc.

output "cluster_id" {
  description = "ID of the GKE cluster"
  value       = "gke-${var.environment}"
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = "gke-${var.environment}"
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = "https://gke-${var.environment}.example.com"
}

output "cluster_ca_certificate" {
  description = "CA certificate of the GKE cluster"
  value       = ""
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = "https://container.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/clusters/gke-${var.environment}"
}

output "kubeconfig" {
  description = "Kubeconfig for the cluster"
  value       = ""
  sensitive   = true
}

output "resource_group_name" {
  description = "Not applicable for GCP"
  value       = ""
}