terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

locals {
  cluster_name = "${var.cluster_name}-${random_pet.suffix.id}"
  resource_group_name = "${var.environment}-aks-rg"
  
  default_node_pools = {
    system = {
      name                = "system"
      vm_size             = "Standard_DS3_v2"
      min_count           = 1
      max_count           = 3
      desired_count       = 1
      enable_spot         = false
      node_labels         = { "kubernetes.azure.com/nodepool-type" = "system" }
      node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
      tags                = {}
    }
    user = {
      name                = "user"
      vm_size             = "Standard_D4s_v5"
      min_count           = 1
      max_count           = 5
      desired_count       = 2
      enable_spot         = var.environment != "prod"
      node_labels         = { "kubernetes.azure.com/nodepool-type" = "user" }
      node_taints         = []
      tags                = {}
    }
  }
  
  merged_node_pools = merge(local.default_node_pools, var.node_pools)
}

resource "azurerm_resource_group" "aks" {
  name     = local.resource_group_name
  location = var.region
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.environment}-aks-logs"
  location            = var.region
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_log_analytics_solution" "this" {
  solution_name         = "ContainerInsights"
  location              = var.region
  resource_group_name   = azurerm_resource_group.aks.name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name
  tags                  = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.environment}-aks"
  kubernetes_version  = var.kubernetes_version

  automatic_upgrade_channel = "patch"

  default_node_pool {
    name       = local.merged_node_pools["system"].name
    vm_size    = local.merged_node_pools["system"].vm_size
    enable_auto_scaling = true
    min_count  = local.merged_node_pools["system"].min_count
    max_count  = local.merged_node_pools["system"].max_count
    node_labels = local.merged_node_pools["system"].node_labels
    node_taints = local.merged_node_pools["system"].node_taints
    tags        = merge(var.tags, local.merged_node_pools["system"].tags)
    
    vnet_subnet_id = var.system_subnet_ids[0]
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = var.enable_cilium ? "cilium" : "azure"
    pod_cidr           = "10.240.0.0/16"
    service_cidr       = "10.245.0.0/16"
    dns_service_ip     = "10.245.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  workload_identity_enabled = var.enable_workload_identity
  oidc_issuer_enabled       = true

  api_server_access_profile {
    enable_private_cluster = var.environment != "dev"
    private_dns_zone       = var.environment != "dev" ? "system" : "none"
    authorized_ip_ranges   = var.environment == "dev" ? ["0.0.0.0/0"] : []
  }

  security_profile {
    azure_key_vault_kms {
      enabled = true
    }
  }

  addon_profile {
    azure_policy {
      enabled = true
    }
    open_service_mesh {
      enabled = false
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

dynamic "node_pool" {
  for_each = var.environment != "dev" ? { for k, v in local.merged_node_pools : k => v if k != "system" } : local.merged_node_pools
  content {
    name           = node_pool.value.name
    vm_size        = node_pool.value.vm_size
    enable_auto_scaling = true
    min_count      = node_pool.value.min_count
    max_count      = node_pool.value.max_count
    node_labels    = node_pool.value.node_labels
    node_taints    = node_pool.value.node_taints
    tags           = merge(var.tags, node_pool.value.tags)
    
    vnet_subnet_id = var.subnet_ids[0]
    
    priority       = node_pool.value.enable_spot ? "Spot" : "Regular"
    eviction_policy = node_pool.value.enable_spot ? "Delete" : null
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user_pools" {
  for_each = { for k, v in local.merged_node_pools : k => v if k != "system" }
  
  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  enable_auto_scaling   = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  tags                  = merge(var.tags, each.value.tags)
  
  vnet_subnet_id        = var.subnet_ids[0]
  
  priority              = each.value.enable_spot ? "Spot" : "Regular"
  eviction_policy       = each.value.enable_spot ? "Delete" : null
}

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.environment}-aks-identity"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_identity_network" {
  scope                = var.vpc_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_role_assignment" "aks_identity_kv" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.environment}-kv-rg"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}