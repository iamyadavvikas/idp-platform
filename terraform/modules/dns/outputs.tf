output "public_zone_id" {
  description = "ID of the public DNS zone"
  value       = module.dns_impl.public_zone_id
}

output "public_zone_name_servers" {
  description = "Name servers for the public DNS zone"
  value       = module.dns_impl.public_zone_name_servers
}

output "private_zone_id" {
  description = "ID of the private DNS zone"
  value       = module.dns_impl.private_zone_id
}