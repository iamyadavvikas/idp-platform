module "kubernetes_impl" {
  source = "./${var.cloud_provider}"

  environment             = var.environment
  region                  = var.region
  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = var.vpc_id
  vpc_cidr                = var.vpc_cidr
  subnet_ids              = var.subnet_ids
  system_subnet_ids       = var.system_subnet_ids
  tags                    = var.tags
  node_pools              = var.node_pools
  enable_workload_identity = var.enable_workload_identity
  enable_cilium           = var.enable_cilium
}