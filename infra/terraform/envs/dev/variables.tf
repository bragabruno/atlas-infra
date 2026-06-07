###############################################################################
# INF-16 — Dev environment variables
#
# All variables have no defaults — they must be supplied via terraform.tfvars
# (gitignored) or -var flags.  See terraform.tfvars.example for guidance.
###############################################################################

# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Azure Resource Group that holds all dev resources."
  type        = string
}

variable "location" {
  description = "Azure region for all resources (e.g. 'westeurope')."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in the dev environment."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    env        = "dev"
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
  default     = "atlas-vnet"
}

variable "vnet_address_space" {
  description = "CIDR block(s) for the VNet. Atlas plan: 10.0.0.0/16."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_system_cidr" {
  description = "CIDR for the AKS system node-pool subnet."
  type        = string
  default     = "10.0.0.0/22"
}

variable "subnet_workload_cidr" {
  description = "CIDR for the AKS workload node-pool subnet."
  type        = string
  default     = "10.0.4.0/22"
}

variable "subnet_data_cidr" {
  description = "CIDR for the data subnet (PostgreSQL + Redis private endpoints)."
  type        = string
  default     = "10.0.8.0/24"
}

# ---------------------------------------------------------------------------
# AKS
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "atlas-aks-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.30"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster FQDN."
  type        = string
  default     = "atlas-dev"
}

variable "system_node_pool_vm_size" {
  description = "VM SKU for the system node pool (burstable dev SKU)."
  type        = string
  default     = "Standard_B2s"
}

variable "system_node_pool_node_count" {
  description = "Fixed node count for the system pool."
  type        = number
  default     = 1
}

variable "workload_node_pool_vm_size" {
  description = "VM SKU for the workload node pool (burstable dev SKU)."
  type        = string
  default     = "Standard_B4ms"
}

variable "workload_node_pool_min_count" {
  description = "Minimum node count for the workload pool autoscaler."
  type        = number
  default     = 0
}

variable "workload_node_pool_max_count" {
  description = "Maximum node count for the workload pool autoscaler."
  type        = number
  default     = 3
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs granted AKS cluster admin role."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where Atlas services run."
  type        = string
  default     = "atlas-dev"
}

variable "services" {
  description = <<-EOT
    Map of Atlas services to their managed identity + role assignment config.
    Passed directly to the identity module.  See identity/variables.tf for schema.
  EOT
  type = map(object({
    kubernetes_namespace = optional(string, "")
    role_assignments = list(object({
      role_definition_name = string
      scope                = string
    }))
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Secrets (Key Vault)
# ---------------------------------------------------------------------------

variable "key_vault_name" {
  description = "Name of the Azure Key Vault (must be globally unique, 3-24 chars)."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID. Required by the Key Vault RBAC configuration."
  type        = string
}

variable "secret_names" {
  description = "List of secret names that will exist in the Key Vault (names only, no values)."
  type        = list(string)
  default = [
    "atlas-pg-password",
    "atlas-redis-password",
    "atlas-openai-api-key",
    "atlas-anthropic-api-key",
  ]
}

variable "gateway_identity_client_id" {
  description = <<-EOT
    Client ID of the gateway managed identity (identity module output
    identity_client_ids[\"gateway\"]).  Used to generate the gateway
    SecretProviderClass template.
  EOT
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Data (PostgreSQL + Redis)
# ---------------------------------------------------------------------------

variable "pg_server_name" {
  description = "Name of the PostgreSQL Flexible Server (globally unique)."
  type        = string
}

variable "pg_admin_username" {
  description = "PostgreSQL administrator login name (initial setup only)."
  type        = string
  default     = "atlasadmin"
}

# ---------------------------------------------------------------------------
# Storage (Blob + ACR)
# ---------------------------------------------------------------------------

variable "storage_account_name" {
  description = "Name of the Azure Storage Account (globally unique, lowercase alphanumeric, 3-24 chars)."
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (globally unique, 5-50 chars, alphanumeric)."
  type        = string
}
