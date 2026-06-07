###############################################################################
# INF-16 — Dev environment remote state backend
#
# PARTIAL backend block — all values supplied at `terraform init` time via
# -backend-config flags.  No environment-specific or sensitive data is
# committed here.
#
# Usage:
#   terraform init \
#     -backend-config="resource_group_name=rg-atlas-tfstate" \
#     -backend-config="storage_account_name=<sa-name>"       \
#     -backend-config="container_name=tfstate"               \
#     -backend-config="key=envs/dev/terraform.tfstate"
#
# The storage account is created by infra/terraform/bootstrap/ on first run.
# Locking: Azure Blob Storage lease-based — no external lock table required.
###############################################################################

terraform {
  backend "azurerm" {
    # All values supplied via -backend-config at init time.
    # Do not hard-code resource_group_name, storage_account_name,
    # container_name, or key here.
  }
}
