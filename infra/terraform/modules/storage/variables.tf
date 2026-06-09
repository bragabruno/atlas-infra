###############################################################################
# Storage Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create storage resources."
  type        = string
}

variable "location" {
  description = "Azure region for all storage resources."
  type        = string
}

# ---------------------------------------------------------------------------
# Network — from network module outputs
# ---------------------------------------------------------------------------

variable "subnet_workload_id" {
  description = "Resource ID of the 'workload' subnet (from network module output subnet_workload_id). Added to the Storage Account network ACL service endpoint allowlist."
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the Atlas Virtual Network (from network module output vnet_id). Used for the ACR private DNS zone VNet link."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace (from observability module output workspace_id). Diagnostic-setting destination for blob read/write/delete logging (CKV2_AZURE_21)."
  type        = string
}

# ---------------------------------------------------------------------------
# Storage Account — Blob
# ---------------------------------------------------------------------------

variable "storage_account_name" {
  description = "Name of the Azure Storage Account. Must be globally unique, 3–24 chars, lowercase alphanumeric only."
  type        = string
}

variable "storage_account_replication_type" {
  description = <<-EOT
    Replication type for the Storage Account.
    Dev default: 'LRS' (locally redundant — cheapest).
    Production: 'ZRS' or 'GRS'.
  EOT
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "storage_account_replication_type must be one of: LRS, ZRS, GRS, RAGRS, GZRS, RAGZRS."
  }
}

variable "storage_account_tier" {
  description = "Performance tier. 'Standard' for Atlas blob workloads."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "storage_account_tier must be 'Standard' or 'Premium'."
  }
}

variable "blob_versioning_enabled" {
  description = "Enable blob versioning on the Storage Account. Allows point-in-time recovery of overwritten blobs."
  type        = bool
  default     = true
}

variable "blob_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs (1–365)."
  type        = number
  default     = 7

  validation {
    condition     = var.blob_delete_retention_days >= 1 && var.blob_delete_retention_days <= 365
    error_message = "blob_delete_retention_days must be between 1 and 365."
  }
}

variable "container_delete_retention_days" {
  description = "Number of days to retain soft-deleted blob containers (1–365)."
  type        = number
  default     = 7

  validation {
    condition     = var.container_delete_retention_days >= 1 && var.container_delete_retention_days <= 365
    error_message = "container_delete_retention_days must be between 1 and 365."
  }
}

# ---------------------------------------------------------------------------
# Blob containers
#
# Atlas containers (from README):
#   golden-sets   — curated evaluation datasets (read-heavy; eval-runner reads, ingestion writes)
#   trace-archive — long-term trace storage (write-heavy; append pattern; cold after 90 d)
#   artifacts     — model artefacts, reports, outputs (mixed read/write)
# ---------------------------------------------------------------------------

variable "blob_containers" {
  description = <<-EOT
    Map of blob container names to their configuration.
    Keys   — container name.
    Values — object with:
      access_type          — 'private' (all Atlas containers are private)
      lifecycle_tier_days  — days until blobs are tiered to Cool storage (0 = disabled)
      lifecycle_delete_days — days until blobs are deleted (0 = disabled)
  EOT
  type = map(object({
    access_type           = optional(string, "private")
    lifecycle_tier_days   = optional(number, 0)
    lifecycle_delete_days = optional(number, 0)
  }))
  default = {
    golden-sets = {
      access_type           = "private"
      lifecycle_tier_days   = 90
      lifecycle_delete_days = 0 # retain indefinitely; manual pruning only
    }
    trace-archive = {
      access_type           = "private"
      lifecycle_tier_days   = 30  # tier to Cool after 30 days (high write volume)
      lifecycle_delete_days = 365 # delete after 1 year
    }
    artifacts = {
      access_type           = "private"
      lifecycle_tier_days   = 90
      lifecycle_delete_days = 730 # delete after 2 years
    }
  }
}

# ---------------------------------------------------------------------------
# Azure Container Registry (ACR)
# ---------------------------------------------------------------------------

variable "acr_name" {
  description = "Name of the Azure Container Registry. Must be globally unique, 5–50 chars, alphanumeric only."
  type        = string
}

variable "acr_sku" {
  description = <<-EOT
    ACR SKU tier.
    Dev default: 'Basic' (cheapest; no geo-replication or private endpoints on Basic).
    Production: 'Premium' (required for private endpoints, geo-replication, quarantine).

    Note: scan-on-push (Defender for Containers / Copilot security scanning) is
    available at all tiers through Microsoft Defender for Containers.
    The quarantine feature requires 'Premium' SKU.
  EOT
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be 'Basic', 'Standard', or 'Premium'."
  }
}

variable "acr_admin_enabled" {
  description = "Enable the ACR admin user. Must remain false for Atlas — authentication is via managed identity / Workload Identity."
  type        = bool
  default     = false
}

variable "acr_public_network_access_enabled" {
  description = "Allow public network access to ACR. Set to false for production. Dev may need true if building images outside VNet."
  type        = bool
  default     = false
}

variable "acr_quarantine_policy_enabled" {
  description = "Enable quarantine policy on ACR. Requires Premium SKU. Prevents unscanned images from being pulled."
  type        = bool
  default     = true
}

variable "acr_retention_policy_days" {
  description = "Number of days to retain untagged manifests before deletion. Requires Premium SKU. 0 = disabled."
  type        = number
  default     = 30
}

variable "acr_trust_policy_enabled" {
  description = "Enable content trust (Notary v1) on ACR. Requires Premium SKU."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all storage resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "storage"
  }
}
