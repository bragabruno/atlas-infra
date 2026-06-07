###############################################################################
# Network Module — Outputs
#
# Downstream modules consume these values:
#   aks module:           subnet_system_id, subnet_workload_id, vnet_id
#   data/secrets modules: subnet_data_id, vnet_id
###############################################################################

output "vnet_id" {
  description = "Resource ID of the Atlas Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the Atlas Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "Address space CIDR(s) assigned to the Virtual Network."
  value       = azurerm_virtual_network.this.address_space
}

# ---------------------------------------------------------------------------
# Subnet IDs — passed to aks and data modules
# ---------------------------------------------------------------------------

output "subnet_system_id" {
  description = "Resource ID of the 'system' subnet (AKS system node pool)."
  value       = azurerm_subnet.system.id
}

output "subnet_system_name" {
  description = "Name of the 'system' subnet."
  value       = azurerm_subnet.system.name
}

output "subnet_system_cidr" {
  description = "Address prefix of the 'system' subnet."
  value       = azurerm_subnet.system.address_prefixes[0]
}

output "subnet_workload_id" {
  description = "Resource ID of the 'workload' subnet (AKS workload node pool)."
  value       = azurerm_subnet.workload.id
}

output "subnet_workload_name" {
  description = "Name of the 'workload' subnet."
  value       = azurerm_subnet.workload.name
}

output "subnet_workload_cidr" {
  description = "Address prefix of the 'workload' subnet."
  value       = azurerm_subnet.workload.address_prefixes[0]
}

output "subnet_data_id" {
  description = "Resource ID of the 'data' subnet (PostgreSQL + Redis private endpoints)."
  value       = azurerm_subnet.data.id
}

output "subnet_data_name" {
  description = "Name of the 'data' subnet."
  value       = azurerm_subnet.data.name
}

output "subnet_data_cidr" {
  description = "Address prefix of the 'data' subnet."
  value       = azurerm_subnet.data.address_prefixes[0]
}

# ---------------------------------------------------------------------------
# NSG IDs
# ---------------------------------------------------------------------------

output "nsg_system_id" {
  description = "Resource ID of the NSG attached to the system subnet."
  value       = azurerm_network_security_group.system.id
}

output "nsg_workload_id" {
  description = "Resource ID of the NSG attached to the workload subnet."
  value       = azurerm_network_security_group.workload.id
}

output "nsg_data_id" {
  description = "Resource ID of the NSG attached to the data subnet."
  value       = azurerm_network_security_group.data.id
}
