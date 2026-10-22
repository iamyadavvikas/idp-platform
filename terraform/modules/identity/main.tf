module "identity_impl" {
  source = "./${var.cloud_provider}"

  environment             = var.environment
  region                  = var.region
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  tags                    = var.tags
  service_accounts        = var.service_accounts
}