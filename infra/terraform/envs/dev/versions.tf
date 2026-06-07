###############################################################################
# INF-16 — Dev env versions
#
# Pins the azurerm provider to the same exact version used by all modules so
# the lock file is deterministic.  Required Terraform version matches the
# module floor (>= 1.9.0); tested against 1.15.5.
###############################################################################

terraform {
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
  #   - CI:    OIDC federated credential (AZURE_CLIENT_ID / AZURE_TENANT_ID)
  #   - Local: az login
  # No ARM_CLIENT_SECRET — ever.
}
