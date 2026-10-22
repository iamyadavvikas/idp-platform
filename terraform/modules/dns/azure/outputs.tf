output "public_zone_id" {
  description = "ID of the public DNS zone"
  value       = var.create_public_zone ? azurerm_dns_zone.public[0].id : ""
}

output "public_zone_name_servers" {
  description = "Name servers for the public DNS zone"
  value       = var.create_public_zone ? azurerm_dns_zone.public[0].name_servers : []
}

output "private_zone_id" {
  description = "ID of the private DNS zone"
  value       = var.create_private_zone ? azurerm_dns_zone.private[0].id : ""
}

output "aks_private_dns_zone_id" {
  description = "ID of the AKS private DNS zone"
  value       = azurerm_private_dns_zone.aks.id
}