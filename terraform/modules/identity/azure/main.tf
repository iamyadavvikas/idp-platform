terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "identity" {
  name     = "${var.environment}-identity-rg"
  location = var.region
  tags     = var.tags
}

locals {
  oidc_issuer = replace(var.cluster_oidc_issuer_url, "https://", "")
}

resource "azurerm_federated_identity_credential" "service_accounts" {
  for_each = var.service_accounts

  name                = "${var.environment}-${each.value.namespace}-${each.value.name}"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = each.value.azure_identity_id

  issuer                = var.cluster_oidc_issuer_url
  subject               = "system:serviceaccount:${each.value.namespace}:${each.value.name}"
  audiences             = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "service_accounts" {
  for_each = var.service_accounts

  scope                = each.value.azure_role_scope
  role_definition_name = each.value.azure_role_name
  principal_id         = each.value.azure_identity_object_id
}