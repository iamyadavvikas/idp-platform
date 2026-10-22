output "storage_account_name" {
  description = "Storage account name for Terraform state"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Container name for Terraform state"
  value       = azurerm_storage_container.state.name
}

output "cosmosdb_account_name" {
  description = "Cosmos DB account name for state locking"
  value       = azurerm_cosmosdb_account.state_lock.name
}

output "cosmosdb_database_name" {
  description = "Cosmos DB database name for state locking"
  value       = azurerm_cosmosdb_sql_database.state_lock.name
}

output "cosmosdb_container_name" {
  description = "Cosmos DB container name for state locking"
  value       = azurerm_cosmosdb_sql_container.state_lock.name
}