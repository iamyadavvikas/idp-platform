module "secrets_impl" {
  source = "./${var.cloud_provider}"

  environment             = var.environment
  region                  = var.region
  tags                    = var.tags
  keyvault_name           = var.keyvault_name
  secrets_manager_name    = var.secrets_manager_name
  secret_manager_project_id = var.secret_manager_project_id
}