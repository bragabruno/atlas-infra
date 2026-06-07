###############################################################################
# Identity Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create managed identities and role assignments."
  type        = string
}

variable "location" {
  description = "Azure region for all managed identity resources."
  type        = string
}

# ---------------------------------------------------------------------------
# AKS OIDC issuer — consumed from aks module output
# ---------------------------------------------------------------------------

variable "oidc_issuer_url" {
  description = <<-EOT
    OIDC issuer URL of the AKS cluster (from aks module output oidc_issuer_url).
    Used to create federated credentials that allow Kubernetes ServiceAccounts to
    exchange tokens for Azure AD access tokens without long-lived secrets.
  EOT
  type        = string
}

variable "kubernetes_namespace" {
  description = "Default Kubernetes namespace where Atlas services run. Used to construct the federated subject claim (system:serviceaccount:<namespace>:<service>)."
  type        = string
  default     = "atlas"
}

# ---------------------------------------------------------------------------
# Service definitions
#
# Each entry in var.services drives:
#   1. A user-assigned managed identity (uami-atlas-<name>)
#   2. A federated credential binding it to the K8s ServiceAccount
#      system:serviceaccount:<kubernetes_namespace>:<name>
#   3. Zero or more role assignments (role → scope)
#
# role_assignments is a list of objects:
#   role_definition_name — built-in role name (e.g. "Key Vault Secrets User")
#   scope                — ARM resource ID the role is scoped to
#                          Use a placeholder like "<key-vault-id>" in .tfvars.example;
#                          supply real IDs in the (gitignored) terraform.tfvars.
# ---------------------------------------------------------------------------

variable "services" {
  description = <<-EOT
    Map of Atlas services to their managed identity + role assignment configuration.

    Keys   — service name (used as identity suffix and K8s ServiceAccount name).
    Values — object with:
      kubernetes_namespace  (optional, overrides var.kubernetes_namespace per-service)
      role_assignments      list of { role_definition_name, scope }

    Example (gateway service):
      gateway = {
        kubernetes_namespace = "atlas"
        role_assignments = [
          { role_definition_name = "Key Vault Secrets User", scope = "<key-vault-id>" },
          { role_definition_name = "Storage Blob Data Reader", scope = "<storage-account-id>" },
        ]
      }
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
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all identity resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "identity"
  }
}
