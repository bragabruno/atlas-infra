###############################################################################
# INF-16 — Dev environment outputs
#
# Expose key values from each module so operators can inspect the environment
# state without digging into individual module outputs.
#
# SENSITIVE outputs are marked sensitive = true so they are redacted in
# `terraform output` and never appear in CI logs.
###############################################################################

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

output "vnet_id" {
  description = "Resource ID of the Atlas VNet."
  value       = module.network.vnet_id
}

output "subnet_system_id" {
  description = "Resource ID of the system subnet."
  value       = module.network.subnet_system_id
}

output "subnet_workload_id" {
  description = "Resource ID of the workload subnet."
  value       = module.network.subnet_workload_id
}

output "subnet_data_id" {
  description = "Resource ID of the data subnet."
  value       = module.network.subnet_data_id
}

# ---------------------------------------------------------------------------
# AKS
# ---------------------------------------------------------------------------

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.cluster_name
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = module.aks.cluster_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster (Workload Identity)."
  value       = module.aks.oidc_issuer_url
}

output "node_resource_group" {
  description = "Auto-generated MC_* node resource group name."
  value       = module.aks.node_resource_group
}

output "kube_config_raw" {
  description = "Raw kubeconfig. Sensitive — use Azure RBAC for day-to-day access."
  value       = module.aks.kube_config_raw
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

output "identity_client_ids" {
  description = "Map of service name → managed identity client ID."
  value       = module.identity.identity_client_ids
}

output "identity_principal_ids" {
  description = "Map of service name → managed identity principal ID."
  value       = module.identity.identity_principal_ids
}

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------

output "key_vault_id" {
  description = "ARM resource ID of the Key Vault."
  value       = module.secrets.key_vault_id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = module.secrets.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = module.secrets.key_vault_uri
}

output "secret_provider_class_yaml" {
  description = "YAML template for the gateway SecretProviderClass. Apply with: terraform output -raw secret_provider_class_yaml | kubectl apply -f -"
  value       = module.secrets.secret_provider_class_yaml
}

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

output "pg_fqdn" {
  description = "PostgreSQL Flexible Server FQDN (private endpoint — resolves within VNet)."
  value       = module.data.pg_fqdn
}

output "redis_hostname" {
  description = "Redis hostname (private endpoint — resolves within VNet)."
  value       = module.data.redis_hostname
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

output "storage_account_name" {
  description = "Name of the Blob Storage Account."
  value       = module.storage.storage_account_name
}

output "acr_login_server" {
  description = "ACR login server (e.g. <name>.azurecr.io). Use in Skaffold --default-repo."
  value       = module.storage.acr_login_server
}
