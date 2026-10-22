output "vpc_id" {
  description = "ID of the VPC/VNet"
  value       = module.networking_impl.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC/VNet"
  value       = module.networking_impl.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking_impl.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking_impl.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.networking_impl.nat_gateway_ids
}

output "availability_zones" {
  description = "Availability zones used"
  value       = module.networking_impl.availability_zones
}