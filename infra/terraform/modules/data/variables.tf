###############################################################################
# Data Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create data resources."
  type        = string
}

variable "location" {
  description = "Azure region for all data resources."
  type        = string
}

# ---------------------------------------------------------------------------
# Network — from network module outputs
# ---------------------------------------------------------------------------

variable "subnet_data_id" {
  description = "Resource ID of the 'data' subnet (from network module output subnet_data_id). Hosts private endpoints for PostgreSQL and Redis."
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the Atlas Virtual Network (from network module output vnet_id). Used for private DNS zone VNet links."
  type        = string
}

# ---------------------------------------------------------------------------
# PostgreSQL Flexible Server
# ---------------------------------------------------------------------------

variable "pg_server_name" {
  description = "Name of the PostgreSQL Flexible Server. Must be globally unique, 3–63 chars, lowercase alphanumeric and hyphens."
  type        = string
  default     = "atlas-pg-dev"
}

variable "pg_version" {
  description = "Major PostgreSQL version. Atlas targets 16 (latest LTS)."
  type        = string
  default     = "16"

  validation {
    condition     = contains(["14", "15", "16"], var.pg_version)
    error_message = "pg_version must be one of: 14, 15, 16."
  }
}

variable "pg_sku_name" {
  description = <<-EOT
    SKU for the PostgreSQL Flexible Server.
    Dev default: B_Standard_B1ms (burstable, 1 vCPU / 2 GB — cost-optimised).
    Production: GP_Standard_D4ds_v5 or similar General Purpose tier.
  EOT
  type        = string
  default     = "B_Standard_B1ms"
}

variable "pg_storage_mb" {
  description = "Storage allocated to the PostgreSQL server in MiB. Dev default: 32768 (32 GiB)."
  type        = number
  default     = 32768

  validation {
    condition     = var.pg_storage_mb >= 32768
    error_message = "pg_storage_mb must be at least 32768 MiB (32 GiB)."
  }
}

variable "pg_storage_tier" {
  description = "Performance tier for PostgreSQL storage. 'P4' is the minimum for B-series SKUs."
  type        = string
  default     = "P4"
}

variable "pg_admin_username" {
  description = "Administrator login name for the PostgreSQL server. Used only for initial setup — workload services authenticate via Entra ID (Microsoft Entra authentication)."
  type        = string
  default     = "atlasadmin"
}

variable "pg_backup_retention_days" {
  description = "Number of days to retain automated PostgreSQL backups (7–35)."
  type        = number
  default     = 7

  validation {
    condition     = var.pg_backup_retention_days >= 7 && var.pg_backup_retention_days <= 35
    error_message = "pg_backup_retention_days must be between 7 and 35."
  }
}

variable "pg_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup for the PostgreSQL server. Set to false for dev (additional cost)."
  type        = bool
  default     = false
}

variable "pg_databases" {
  description = <<-EOT
    Map of database names to create on the PostgreSQL server.
    Key   — database name.
    Value — object with charset and collation.
  EOT
  type = map(object({
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.utf8")
  }))
  default = {
    atlas = {
      charset   = "UTF8"
      collation = "en_US.utf8"
    }
  }
}

# ---------------------------------------------------------------------------
# Redis Cache (Azure Cache for Redis)
# ---------------------------------------------------------------------------

variable "redis_name" {
  description = "Name of the Azure Cache for Redis. Must be globally unique, 1–63 chars, alphanumeric and hyphens."
  type        = string
  default     = "atlas-redis-dev"
}

variable "redis_capacity" {
  description = <<-EOT
    Cache capacity (size). For 'Basic' and 'Standard' tiers: 0–6 (C0–C6).
    For 'Premium' tier: 1–5 (P1–P5).
    Dev default: 0 (C0, 250 MB — cheapest Basic tier).
  EOT
  type        = number
  default     = 0
}

variable "redis_family" {
  description = "Redis family. 'C' for Basic/Standard, 'P' for Premium."
  type        = string
  default     = "C"

  validation {
    condition     = contains(["C", "P"], var.redis_family)
    error_message = "redis_family must be 'C' or 'P'."
  }
}

variable "redis_sku_name" {
  description = "Redis SKU tier. Dev default: 'Basic'. Use 'Standard' or 'Premium' for production (HA, geo-replication)."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "redis_sku_name must be 'Basic', 'Standard', or 'Premium'."
  }
}

variable "redis_non_ssl_port_enabled" {
  description = "Allow non-TLS connections (port 6379). Must be false for Atlas — all connections use TLS (port 6380)."
  type        = bool
  default     = false
}

variable "redis_minimum_tls_version" {
  description = "Minimum TLS version for Redis connections."
  type        = string
  default     = "1.2"
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all data resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "data"
  }
}
