terraform {
  required_version = ">= 1.5"
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

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  storage_account_name = "idpterraformstate${random_string.suffix.result}"
  container_name       = "tfstate"
}

resource "azurerm_resource_group" "state" {
  name     = "idp-terraform-state-rg"
  location = var.region
  tags     = var.tags
}

resource "azurerm_storage_account" "state" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  enable_https_traffic_only = true
  min_tls_version          = "TLS1_2"
  public_network_access_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  name                  = local.container_name
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

resource "azurerm_cosmosdb_account" "state_lock" {
  name                = "idp-tf-lock-${random_string.suffix.result}"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = var.region
    failover_priority = 0
  }
  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "state_lock" {
  name                = "tf-lock"
  resource_group_name = azurerm_resource_group.state.name
  account_name        = azurerm_cosmosdb_account.state_lock.name
}

resource "azurerm_cosmosdb_sql_container" "state_lock" {
  name                = "locks"
  resource_group_name = azurerm_resource_group.state.name
  account_name        = azurerm_cosmosdb_account.state_lock.name
  database_name       = azurerm_cosmosdb_sql_database.state_lock.name
  partition_key_path  = "/LockID"
  throughput          = 400
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}

output "cosmosdb_account_name" {
  value = azurerm_cosmosdb_account.state_lock.name
}

output "cosmosdb_database_name" {
  value = azurerm_cosmosdb_sql_database.state_lock.name
}

output "cosmosdb_container_name" {
  value = azurerm_cosmosdb_sql_container.state_lock.name
}