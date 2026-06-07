###############################################################################
# Remote State Backend — azurerm (Azure Blob Storage)
#
# This file contains a PARTIAL backend block.  All values are intentionally
# left empty and must be supplied at `terraform init` time via -backend-config
# flags so that no environment-specific or sensitive data is committed.
#
# Usage:
#   terraform init \
#     -backend-config="resource_group_name=<rg>"           \
#     -backend-config="storage_account_name=<sa>"          \
#     -backend-config="container_name=tfstate"             \
#     -backend-config="key=envs/<ENV>/terraform.tfstate"
#
# The bootstrap module (infra/terraform/bootstrap/) creates the Storage
# Account and container on first run.  See bootstrap/README.md.
#
# Locking: Azure Blob Storage provides native lease-based locking.
# No external lock table (DynamoDB-equivalent) is required.
###############################################################################

terraform {
  backend "azurerm" {
    # All values supplied via -backend-config at init time.
    # Do not hard-code resource_group_name, storage_account_name,
    # container_name, or key here.
  }
}
