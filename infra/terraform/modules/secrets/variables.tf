###############################################################################
# Secrets Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create Key Vault and related resources."
  type        = string
}

variable "location" {
  description = "Azure region for all secrets resources."
  type        = string
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------

variable "key_vault_name" {
  description = <<-EOT
    Name of the Azure Key Vault. Must be globally unique, 3–24 characters,
    alphanumeric and hyphens only.
  EOT
  type        = string
  default     = "atlas-kv-dev"
}

variable "key_vault_sku_name" {
  description = "SKU tier for the Key Vault. 'standard' is sufficient for Atlas dev."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku_name)
    error_message = "key_vault_sku_name must be 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted Key Vault objects (7–90). Azure default is 90."
  type        = number
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "purge_protection_enabled" {
  description = "Enable purge protection on the Key Vault. Set to true for production to prevent accidental permanent deletion."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Azure AD / Tenant
# ---------------------------------------------------------------------------

variable "tenant_id" {
  description = "Azure AD tenant ID. Used for Key Vault access policy (RBAC mode — no access policies are created by this module)."
  type        = string
}

# ---------------------------------------------------------------------------
# Network — subnet for private endpoint
# ---------------------------------------------------------------------------

variable "subnet_data_id" {
  description = "Resource ID of the 'data' subnet (from network module output subnet_data_id). Used for the Key Vault private endpoint."
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the Atlas Virtual Network (from network module output vnet_id). Used for the private DNS zone VNet link."
  type        = string
}

# ---------------------------------------------------------------------------
# Secret names (references only — no values)
#
# These names drive the SecretProviderClass template.  The secrets themselves
# must be created out-of-band (e.g. via `az keyvault secret set` or a
# secrets-management pipeline) before pods that mount them are scheduled.
# ---------------------------------------------------------------------------

variable "secret_names" {
  description = <<-EOT
    List of secret names that exist (or will exist) in the Key Vault.
    These names are referenced in the SecretProviderClass template output
    but NO secret values are stored in Terraform state.

    Example:
      ["atlas-pg-password", "atlas-redis-password", "atlas-openai-api-key"]
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# SecretProviderClass template
# ---------------------------------------------------------------------------

variable "kubernetes_namespace" {
  description = "Kubernetes namespace used in the SecretProviderClass template. Must match the namespace where Atlas services are deployed."
  type        = string
  default     = "atlas"
}

variable "identity_client_id" {
  description = <<-EOT
    Client ID of the user-assigned managed identity (from identity module output
    identity_client_ids[<service>]) to use in the SecretProviderClass template.
    Each service gets its own SecretProviderClass; supply the relevant client ID.
  EOT
  type        = string
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all secrets resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "secrets"
  }
}
