###############################################################################
# INF-7 — Secrets Module
#
# Provisions:
#   - Azure Key Vault (RBAC-authorised, private endpoint, soft-delete)
#   - Private DNS zone for Key Vault (privatelink.vaultcore.azure.net)
#   - Private endpoint in the data subnet
#   - SecretProviderClass template (rendered as a local_file output or passed
#     as a Terraform output for Helm/kubectl apply — no secret values stored)
#
# No secret VALUES are stored here.  Secret names (references) are provided
# via var.secret_names and rendered into the SecretProviderClass template.
#
# Workload Identity model (from README):
#   Pod SA → OIDC federation → UAMI → Key Vault RBAC role
#     → Secrets Store CSI driver → SecretProviderClass → in-memory mount
#
# The AKS add-on (key_vault_secrets_provider) is enabled in the aks module.
# This module provides the Key Vault instance and a reusable template.
#
# Dependency order (from README): network → aks → identity → secrets
###############################################################################

###############################################################################
# Key Vault
#
# enable_rbac_authorization = true: uses Azure RBAC (not access policies) so
# role assignments in the identity module control secret access without
# touching vault-level access policies.
# soft_delete_retention_days / purge_protection: configurable per environment
# (dev uses shorter retention + no purge protection for agility).
###############################################################################

resource "azurerm_key_vault" "this" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.key_vault_sku_name

  # RBAC mode — no access policies; roles granted via identity module
  rbac_authorization_enabled = true

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Disable public network access: all traffic via private endpoint
  public_network_access_enabled = false

  # Allow Azure services (e.g. Secrets Store CSI) to bypass the network ACL
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = []
  }

  tags = var.tags
}

###############################################################################
# Private DNS zone for Key Vault
#
# privatelink.vaultcore.azure.net resolves vault.azure.net FQDNs to private
# endpoint IPs within the VNet so pods reach Key Vault without leaving the
# Azure backbone.
###############################################################################

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "pdnslink-kv-atlas-vnet"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

###############################################################################
# Private endpoint — Key Vault
#
# Placed in the data subnet (same subnet as PostgreSQL and Redis private
# endpoints; the data NSG already permits workload → data traffic).
###############################################################################

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${var.key_vault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-${var.key_vault_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = var.tags
}
