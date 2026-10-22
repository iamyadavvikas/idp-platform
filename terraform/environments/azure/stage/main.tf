terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "idp-terraform-state-rg"
    storage_account_name = "idpterraformstate"
    container_name       = "tfstate"
    key                  = "azure/stage/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "kubernetes" {
  host                   = module.kubernetes.cluster_endpoint
  cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = ["get-token", "--server-id", module.kubernetes.cluster_endpoint]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.kubernetes.cluster_endpoint
    cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = ["get-token", "--server-id", module.kubernetes.cluster_endpoint]
    }
  }
}

module "networking" {
  source = "../../../modules/networking"

  cloud_provider       = "azure"
  environment          = var.environment
  region               = var.region
  cidr_block           = var.vpc_cidr
  az_count             = var.az_count
  enable_nat_gateway   = var.enable_nat_gateway
  tags                 = var.tags
}

module "kubernetes" {
  source = "../../../modules/kubernetes"

  cloud_provider             = "azure"
  environment                = var.environment
  region                     = var.region
  cluster_name               = "${var.environment}-${var.cluster_name}"
  kubernetes_version         = var.kubernetes_version
  vpc_id                     = module.networking.vpc_id
  vpc_cidr                   = module.networking.vpc_cidr
  subnet_ids                 = module.networking.private_subnet_ids
  system_subnet_ids          = module.networking.system_subnet_ids
  tags                       = var.tags
  enable_workload_identity   = true
  enable_cilium              = true
  node_pools = {
    system = {
      vm_size             = "Standard_DS3_v2"
      min_count           = 1
      max_count           = 5
      desired_count       = 2
      enable_spot         = false
      node_labels         = { "kubernetes.azure.com/nodepool-type" = "system" }
      node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
      tags                = {}
    }
    user = {
      vm_size             = "Standard_D4s_v5"
      min_count           = 2
      max_count           = 10
      desired_count       = 4
      enable_spot         = true
      node_labels         = { "kubernetes.azure.com/nodepool-type" = "user" }
      node_taints         = []
      tags                = {}
    }
  }
}

module "secrets" {
  source = "../../../modules/secrets"

  cloud_provider = "azure"
  environment    = var.environment
  region         = var.region
  tags           = var.tags
  vpc_id         = module.networking.vpc_id
  subnet_ids     = module.networking.private_subnet_ids
}

module "dns" {
  source = "../../../modules/dns"

  cloud_provider      = "azure"
  environment         = var.environment
  region              = var.region
  domain_name         = var.domain_name
  tags                = var.tags
  create_public_zone  = false
  create_private_zone = true
  vpc_id              = module.networking.vpc_id
}

module "identity" {
  source = "../../../modules/identity"

  cloud_provider             = "azure"
  environment                = var.environment
  region                     = var.region
  cluster_oidc_issuer_url    = module.kubernetes.oidc_issuer_url
  tags                       = var.tags
  service_accounts = {
    external_secrets = {
      namespace                = "external-secrets"
      name                     = "external-secrets"
      description              = "External Secrets Operator"
      azure_identity_id        = module.secrets.identity_client_id
      azure_identity_client_id = module.secrets.identity_client_id
      azure_identity_object_id = module.secrets.identity_object_id
      azure_role_scope         = module.secrets.keyvault_id
      azure_role_name          = "Key Vault Secrets User"
      aws_policy_arns          = []
      gcp_roles                = []
    }
    flux_image_automation = {
      namespace                = "flux-system"
      name                     = "flux-image-automation"
      description              = "Flux Image Automation Controller"
      azure_identity_id        = ""
      azure_identity_client_id = ""
      azure_identity_object_id = ""
      azure_role_scope         = ""
      azure_role_name          = ""
      aws_policy_arns          = []
      gcp_roles                = []
    }
  }
}

output "cluster_name" {
  value = module.kubernetes.cluster_name
}

output "cluster_endpoint" {
  value = module.kubernetes.cluster_endpoint
}

output "vnet_id" {
  value = module.networking.vpc_id
}

output "keyvault_uri" {
  value = module.secrets.keyvault_uri
}

output "keyvault_id" {
  value = module.secrets.keyvault_id
}