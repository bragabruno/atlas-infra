###############################################################################
# INF-9 — Storage Module
#
# Provisions:
#   - Azure Storage Account
#       · Blob versioning + soft-delete enabled
#       · Three containers: golden-sets, trace-archive, artifacts
#       · Lifecycle rules per container (tier-to-Cool + delete)
#       · Service endpoint ACL: workload subnet only; public access denied
#   - Azure Container Registry (ACR)
#       · Premium SKU (scan-on-push / quarantine / retention policy)
#       · Admin user disabled — auth via managed identity (Workload Identity)
#       · Scan-on-push enforced via quarantine policy
#       · Retention policy: delete untagged manifests after N days
#       · Private endpoint in workload subnet (Premium SKU required)
#       · Private DNS zone: privatelink.azurecr.io
#
# Dependency order (from README): network → aks → identity → … → storage
###############################################################################

###############################################################################
# Storage Account
###############################################################################

resource "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  location            = var.location
  resource_group_name = var.resource_group_name

  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind             = "StorageV2"

  # Enforce HTTPS; deny HTTP
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  # Deny all public blob access; service endpoint allowlist controls access
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  # Blob versioning and soft-delete for point-in-time recovery
  blob_properties {
    versioning_enabled = var.blob_versioning_enabled

    delete_retention_policy {
      days = var.blob_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_delete_retention_days
    }
  }

  # Network ACLs — deny by default; allow from workload subnet service endpoint
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.subnet_workload_id]
    ip_rules                   = []
  }

  tags = var.tags
}

###############################################################################
# Blob Containers
###############################################################################

resource "azurerm_storage_container" "this" {
  for_each = var.blob_containers

  name                  = each.key
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = each.value.access_type
}

###############################################################################
# Blob Lifecycle Management Rules
#
# One rule per container that has lifecycle_tier_days or lifecycle_delete_days
# set to a non-zero value.
###############################################################################

locals {
  # Only containers with at least one lifecycle action configured
  lifecycle_containers = {
    for name, cfg in var.blob_containers :
    name => cfg
    if cfg.lifecycle_tier_days > 0 || cfg.lifecycle_delete_days > 0
  }
}

resource "azurerm_storage_management_policy" "this" {
  count              = length(local.lifecycle_containers) > 0 ? 1 : 0
  storage_account_id = azurerm_storage_account.this.id

  dynamic "rule" {
    for_each = local.lifecycle_containers
    content {
      name    = "lifecycle-${rule.key}"
      enabled = true

      filters {
        blob_types   = ["blockBlob"]
        prefix_match = ["${rule.key}/"]
      }

      actions {
        base_blob {
          # Tier to Cool after N days (only when tier_days > 0)
          tier_to_cool_after_days_since_modification_greater_than = (
            rule.value.lifecycle_tier_days > 0 ? rule.value.lifecycle_tier_days : null
          )

          # Delete after N days (only when delete_days > 0)
          delete_after_days_since_modification_greater_than = (
            rule.value.lifecycle_delete_days > 0 ? rule.value.lifecycle_delete_days : null
          )
        }
      }
    }
  }
}

###############################################################################
# Azure Container Registry
###############################################################################

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.acr_sku

  # Admin user disabled — services authenticate via managed identity
  admin_enabled = var.acr_admin_enabled

  public_network_access_enabled = var.acr_public_network_access_enabled

  # Quarantine policy: images must pass vulnerability scan before pull is allowed
  # Requires Premium SKU
  quarantine_policy_enabled = var.acr_sku == "Premium" ? var.acr_quarantine_policy_enabled : false

  # Retention policy: remove untagged manifests after N days (flat attribute in azurerm 4.x)
  # Requires Premium SKU; 0 disables it
  retention_policy_in_days = var.acr_sku == "Premium" ? var.acr_retention_policy_days : 0

  # Trust policy (Notary v1 content trust) — flat attribute in azurerm 4.x
  # Requires Premium SKU
  trust_policy_enabled = var.acr_sku == "Premium" ? var.acr_trust_policy_enabled : false

  tags = var.tags
}

###############################################################################
# Private DNS zone — ACR
#
# privatelink.azurecr.io resolves <registry>.azurecr.io to the private
# endpoint IP so AKS nodes pull images without traversing the public internet.
# Requires Premium SKU.
###############################################################################

resource "azurerm_private_dns_zone" "acr" {
  count               = var.acr_sku == "Premium" ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.acr_sku == "Premium" ? 1 : 0
  name                  = "pdnslink-acr-atlas-vnet"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

###############################################################################
# Private endpoint — ACR
# Requires Premium SKU.
###############################################################################

resource "azurerm_private_endpoint" "acr" {
  count               = var.acr_sku == "Premium" ? 1 : 0
  name                = "pe-${var.acr_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_workload_id

  private_service_connection {
    name                           = "psc-${var.acr_name}"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-${var.acr_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = var.tags
}
