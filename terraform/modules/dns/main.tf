module "dns_impl" {
  source = "./${var.cloud_provider}"

  environment       = var.environment
  region            = var.region
  domain_name       = var.domain_name
  tags              = var.tags
  create_public_zone = var.create_public_zone
  create_private_zone = var.create_private_zone
}