###############################################################################
# INF-8 — Data Module
#
# Provisions:
#   - Azure Database for PostgreSQL Flexible Server
#       · Dev SKU (burstable B_Standard_B1ms), single-AZ
#       · Private endpoint in data subnet; public access disabled
#       · Private DNS zone: privatelink.postgres.database.azure.com
#       · Microsoft Entra authentication enabled (workload identities use it)
#       · Database(s) created via azurerm_postgresql_flexible_server_database
#   - Azure Cache for Redis (Basic C0 for dev)
#       · TLS-only (port 6380); non-SSL disabled
#       · Private endpoint in data subnet; public access disabled
#       · Private DNS zone: privatelink.redis.cache.windows.net
#
# NO passwords or connection strings appear in outputs or state.
# The admin password for PostgreSQL is marked sensitive and stored only in
# Terraform state (which is encrypted at rest in Azure Blob Storage).
# Workload services connect via Entra ID managed identity authentication —
# no password needed at runtime.
#
# Dependency order (from README): network → aks → identity → secrets → data
###############################################################################

###############################################################################
# PostgreSQL Flexible Server
###############################################################################

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.pg_server_name
  location            = var.location
  resource_group_name = var.resource_group_name

  version  = var.pg_version
  sku_name = var.pg_sku_name

  storage_mb   = var.pg_storage_mb
  storage_tier = var.pg_storage_tier

  # single-AZ for dev (zone = "" lets Azure choose)
  zone = "1"

  # Administrator credentials — used only for initial setup / emergency break-glass.
  # Atlas services authenticate via Entra ID managed identity; no password is
  # surfaced in any outputs from this module.
  administrator_login    = var.pg_admin_username
  administrator_password = random_password.pg_admin.result

  backup_retention_days        = var.pg_backup_retention_days
  geo_redundant_backup_enabled = var.pg_geo_redundant_backup_enabled

  # Disable public network access; all traffic via private endpoint
  public_network_access_enabled = false

  # Microsoft Entra authentication — allows managed identities to authenticate
  # without passwords (Atlas NFR2: no plaintext credentials at runtime)
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true # required while pg_admin exists; disable after migration
  }

  tags = var.tags
}

###############################################################################
# Random admin password
#
# Generated once, stored in Terraform state (encrypted).
# Never exposed in outputs. Services use Entra ID auth, not this password.
###############################################################################

resource "random_password" "pg_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

###############################################################################
# PostgreSQL Databases
###############################################################################

resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each = var.pg_databases

  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = each.value.charset
  collation = each.value.collation
}

###############################################################################
# Private DNS zone — PostgreSQL
###############################################################################

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdnslink-pg-atlas-vnet"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

###############################################################################
# Private endpoint — PostgreSQL
###############################################################################

resource "azurerm_private_endpoint" "postgres" {
  name                = "pe-${var.pg_server_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id

  private_service_connection {
    name                           = "psc-${var.pg_server_name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-${var.pg_server_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgres.id]
  }

  tags = var.tags
}

###############################################################################
# Azure Cache for Redis
###############################################################################

resource "azurerm_redis_cache" "this" {
  name                = var.redis_name
  location            = var.location
  resource_group_name = var.resource_group_name

  capacity = var.redis_capacity
  family   = var.redis_family
  sku_name = var.redis_sku_name

  # TLS only — port 6380; port 6379 disabled
  non_ssl_port_enabled = var.redis_non_ssl_port_enabled
  minimum_tls_version  = var.redis_minimum_tls_version

  # Disable public access — all traffic via private endpoint
  public_network_access_enabled = false

  redis_configuration {}

  tags = var.tags
}

###############################################################################
# Private DNS zone — Redis
###############################################################################

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "pdnslink-redis-atlas-vnet"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

###############################################################################
# Private endpoint — Redis
###############################################################################

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-${var.redis_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id

  private_service_connection {
    name                           = "psc-${var.redis_name}"
    private_connection_resource_id = azurerm_redis_cache.this.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-${var.redis_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = var.tags
}
