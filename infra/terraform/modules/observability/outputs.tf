###############################################################################
# Observability Module — Outputs
#
# Consumed by:
#   aks module:     log_analytics_workspace_id (oms_agent add-on)
#   storage module: log_analytics_workspace_id (diagnostic settings)
###############################################################################

output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}
