###############################################################################
# Storage Module — Outputs
#
# Downstream consumers:
#   identity module: storage_account_id / acr_id (role assignment scopes)
#   Helm values:     storage_account_name, acr_login_server (no credentials)
#   AKS:             acr_id (for AKS → ACR attach via AcrPull role)
###############################################################################

# ---------------------------------------------------------------------------
# Storage Account
# ---------------------------------------------------------------------------

output "storage_account_id" {
  description = "ARM resource ID of the Storage Account."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = azurerm_storage_account.this.name
}

output "storage_account_primary_blob_endpoint" {
  description = <<-EOT
    Primary blob service endpoint URL.
    Use this as the base URL for blob references in application config.
    Authentication is via Workload Identity — no access keys in config.
  EOT
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "blob_container_ids" {
  description = "Map of container name → resource ID."
  value = {
    for name, container in azurerm_storage_container.this :
    name => container.id
  }
}

# ---------------------------------------------------------------------------
# Azure Container Registry
# ---------------------------------------------------------------------------

output "acr_id" {
  description = "ARM resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.this.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.this.name
}

output "acr_login_server" {
  description = <<-EOT
    Login server hostname for the ACR (e.g. <name>.azurecr.io).
    Use as the image registry in Helm values / Kubernetes manifests.
    AKS nodes authenticate via the AcrPull role assignment (no passwords).
  EOT
  value       = azurerm_container_registry.this.login_server
}

output "acr_private_endpoint_ip" {
  description = "Private IP address of the ACR private endpoint NIC. Only set when acr_sku = 'Premium'."
  value = (
    var.acr_sku == "Premium"
    ? azurerm_private_endpoint.acr[0].private_service_connection[0].private_ip_address
    : null
  )
}
