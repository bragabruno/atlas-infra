###############################################################################
# Data Module — Outputs
#
# NO passwords or connection strings are exposed here.
# Workload services obtain the admin password via Key Vault (secrets module)
# and authenticate via Entra ID managed identity — no credentials in outputs.
#
# Downstream consumers:
#   secrets module: pg_server_id / redis_id (optional, for Key Vault-scoped roles)
#   identity module: pg_server_id / redis_id (role assignment scopes)
#   Helm values: pg_fqdn / redis_hostname (host-only, no credentials)
###############################################################################

# ---------------------------------------------------------------------------
# PostgreSQL Flexible Server
# ---------------------------------------------------------------------------

output "pg_server_id" {
  description = "ARM resource ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "pg_server_name" {
  description = "Name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "pg_fqdn" {
  description = <<-EOT
    Fully-qualified domain name of the PostgreSQL Flexible Server.
    Resolves to the private endpoint IP within the VNet.
    Use this as the host in application connection strings — supply
    credentials via Key Vault at runtime, never in config.
  EOT
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "pg_database_names" {
  description = "Set of database names created on the PostgreSQL server."
  value       = keys(azurerm_postgresql_flexible_server_database.this)
}

output "pg_private_endpoint_ip" {
  description = "Private IP address of the PostgreSQL private endpoint NIC."
  value       = azurerm_private_endpoint.postgres.private_service_connection[0].private_ip_address
}

# ---------------------------------------------------------------------------
# Redis Cache
# ---------------------------------------------------------------------------

output "redis_id" {
  description = "ARM resource ID of the Azure Cache for Redis."
  value       = azurerm_redis_cache.this.id
}

output "redis_name" {
  description = "Name of the Azure Cache for Redis."
  value       = azurerm_redis_cache.this.name
}

output "redis_hostname" {
  description = <<-EOT
    Hostname of the Redis cache.
    Resolves to the private endpoint IP within the VNet.
    Use this as the host in application connection strings — supply
    the access key via Key Vault at runtime, never in config.
  EOT
  value       = azurerm_redis_cache.this.hostname
}

output "redis_ssl_port" {
  description = "TLS port for Redis connections (always 6380 for Atlas)."
  value       = azurerm_redis_cache.this.ssl_port
}

output "redis_private_endpoint_ip" {
  description = "Private IP address of the Redis private endpoint NIC."
  value       = azurerm_private_endpoint.redis.private_service_connection[0].private_ip_address
}
