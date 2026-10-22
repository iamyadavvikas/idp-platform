module "networking_impl" {
  source = "./${var.cloud_provider}"

  environment       = var.environment
  region            = var.region
  cidr_block        = var.cidr_block
  az_count          = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  tags              = var.tags
}