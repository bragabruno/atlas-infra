###############################################################################
# Observability Module
#
# Provisions a Log Analytics workspace that serves as the diagnostic
# destination for:
#   - AKS control-plane / container insights (aks module `oms_agent` add-on)
#   - Storage blob + queue read/write/delete logging (storage module
#     azurerm_monitor_diagnostic_setting)
#
# Dev-sized: PerGB2018 SKU, 30-day retention. Raise retention for production.
#
# Depends only on the resource group + location, so it can be created ahead of
# the aks and storage modules that consume its workspace ID.
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = var.sku
  retention_in_days = var.retention_in_days

  tags = var.tags
}
