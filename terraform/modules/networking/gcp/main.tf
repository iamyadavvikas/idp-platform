# GCP Networking Module - Stub Implementation
# TODO: Implement full GCP VPC with Cloud NAT, Private Service Connect, etc.

output "vpc_id" {
  description = "ID of the VPC"
  value       = "gcp-vpc-${var.environment}"
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = var.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = []
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = []
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = []
}

output "availability_zones" {
  description = "Availability zones used"
  value       = []
}