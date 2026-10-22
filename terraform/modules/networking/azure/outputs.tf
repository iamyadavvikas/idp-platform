output "vpc_id" {
  description = "ID of the VNet"
  value       = azurerm_virtual_network.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VNet"
  value       = var.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = azurerm_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = azurerm_subnet.private[*].id
}

output "system_subnet_ids" {
  description = "IDs of system subnets (for AKS system node pool)"
  value       = azurerm_subnet.system[*].id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.this[*].id : []
}

output "availability_zones" {
  description = "Availability zones used"
  value       = [for i in range(var.az_count) : "${var.region}-${i+1}"]
}

output "resource_group_name" {
  description = "Name of the network resource group"
  value       = azurerm_resource_group.network.name
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone"
  value       = azurerm_private_dns_zone.this.id
}