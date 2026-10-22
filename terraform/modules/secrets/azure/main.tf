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

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  keyvault_name = var.keyvault_name != "" ? var.keyvault_name : "${var.environment}-kv-${random_string.suffix.result}"
  resource_group_name = "${var.environment}-kv-rg"
}

resource "azurerm_resource_group" "kv" {
  name     = local.resource_group_name
  location = var.region
  tags     = var.tags
}

resource "azurerm_key_vault" "this" {
  name                        = local.keyvault_name
  location                    = azurerm_resource_group.kv.location
  resource_group_name         = azurerm_resource_group.kv.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = var.environment == "prod"
  soft_delete_retention_days  = 90
  public_network_access_enabled = var.environment == "dev"

  network_acls {
    default_action = var.environment == "prod" ? "Deny" : "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "external_secrets" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
  ]
  key_permissions = [
    "Get", "List", "Create", "Delete", "Recover", "Backup", "Restore"
  ]
  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Recover", "Backup", "Restore"
  ]
}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "${var.environment}-external-secrets"
  location            = azurerm_resource_group.kv.location
  resource_group_name = azurerm_resource_group.kv.name
  tags                = var.tags
}

resource "azurerm_key_vault_access_policy" "external_secrets_identity" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.external_secrets.principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.environment}-kv-pe"
  location            = azurerm_resource_group.kv.location
  resource_group_name = azurerm_resource_group.kv.name
  subnet_id           = var.subnet_ids[0]
  tags                = var.tags

  private_service_connection {
    name                           = "${var.environment}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.kv.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.environment}-kv-dns-link"
  resource_group_name   = azurerm_resource_group.kv.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = var.vpc_id
  registration_enabled  = false
}

resource "azurerm_key_vault_secret" "demo_db_password" {
  name         = "demo-app-db-password"
  value        = "changeme-${var.environment}"
  key_vault_id = azurerm_key_vault.this.id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "demo_api_key" {
  name         = "demo-app-api-key"
  value        = "changeme-${var.environment}"
  key_vault_id = azurerm_key_vault.this.id
  tags         = var.tags
}