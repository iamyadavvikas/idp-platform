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

resource "azurerm_resource_group" "dns" {
  name     = "${var.environment}-dns-rg"
  location = "global"
  tags     = var.tags
}

resource "azurerm_dns_zone" "public" {
  count               = var.create_public_zone ? 1 : 0
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}

resource "azurerm_dns_zone" "private" {
  count               = var.create_private_zone ? 1 : 0
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}

resource "azurerm_dns_a_record" "wildcard" {
  count               = var.create_public_zone ? 1 : 0
  name                = "*"
  zone_name           = azurerm_dns_zone.public[0].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  records             = ["1.2.3.4"] # Placeholder - updated by External DNS / Application Gateway
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${var.region}.azmk8s.io"
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "${var.environment}-aks-dns-link"
  resource_group_name   = azurerm_resource_group.dns.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = var.vpc_id
  registration_enabled  = false
}