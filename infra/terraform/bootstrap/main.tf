###############################################################################
# INF-3 — Terraform State Backend Bootstrap
#
# ONE-TIME SETUP: Run this with a local backend before switching any other
# module to the remote azurerm backend.  See README.md for the full workflow.
#
# Resources created:
#   - Resource Group           (atlas-tfstate or custom name)
#   - Storage Account          (LRS, TLS-only, versioning enabled)
#   - Blob Container "tfstate" (private; lease-based locking by azurerm)
###############################################################################

terraform {
  # Bootstrap must run with a LOCAL backend — the remote storage doesn't exist
  # yet.  Do NOT add an azurerm backend block here.
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.74.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Authenticate via:
  #   - CI:    OIDC federated credential (no ARM_CLIENT_SECRET)
  #   - Local: az login
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Storage Account
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "tfstate" {
  # --- Documented exceptions — this is the one-time Terraform state backend ---
  # account (local-backend bootstrap), which has fundamentally different
  # constraints from the application storage. Hardened equivalents live in the
  # storage module; the state account must stay simple and reachable.
  #checkov:skip=CKV2_AZURE_40:The azurerm backend requires shared-key auth (shared_access_key_enabled=true); disabling it breaks state access.
  #checkov:skip=CKV_AZURE_59:The tfstate account must stay reachable from CI/local for the azurerm backend; locking down public access would block state operations.
  #checkov:skip=CKV2_AZURE_33:A private-endpoint-only tfstate account would lock out the azurerm backend from CI/local; out of scope for a one-time bootstrap.
  #checkov:skip=CKV2_AZURE_1:tfstate uses platform-managed keys; CMK adds a Key Vault dependency that does not exist at bootstrap time (this runs before any vault).
  #checkov:skip=CKV_AZURE_206:Dev tfstate uses LRS by cost; GRS is a prod-DR choice.
  #checkov:skip=CKV2_AZURE_41:State access uses shared-key backend auth, not SAS tokens; a SAS expiration policy does not apply.
  #checkov:skip=CKV_AZURE_33:The tfstate account uses only the blob service for state; no queue service is in use.

  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location

  account_tier             = "Standard"
  account_replication_type = "LRS" # Upgrade to GRS if cross-region DR is required

  # Security hardening
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # Required for azurerm backend auth

  # Soft-delete / versioning protects state files from accidental overwrites
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Blob Container — "tfstate"
#
# Azure Blob Storage provides lease-based locking natively; no external lock
# table (DynamoDB-style) is required.  The azurerm backend acquires a lease
# before writing and releases it on completion or timeout.
# ---------------------------------------------------------------------------

resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging needs a Log Analytics workspace; the one-time local-backend bootstrap runs before any observability infra exists.
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
