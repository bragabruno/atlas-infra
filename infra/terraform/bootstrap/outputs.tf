output "resource_group_name" {
  description = "Name of the resource group holding the state backend resources."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Name of the Storage Account used as the Terraform state backend."
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  description = "Name of the blob container that holds state files."
  value       = azurerm_storage_container.tfstate.name
}

output "primary_blob_endpoint" {
  description = "Primary blob service endpoint URL for the state Storage Account."
  value       = azurerm_storage_account.tfstate.primary_blob_endpoint
}

output "backend_config_hint" {
  description = "Copy-paste hint for -backend-config flags in downstream terraform init calls."
  value       = <<-EOT
    terraform init \
      -backend-config="resource_group_name=${azurerm_resource_group.tfstate.name}" \
      -backend-config="storage_account_name=${azurerm_storage_account.tfstate.name}" \
      -backend-config="container_name=${azurerm_storage_container.tfstate.name}" \
      -backend-config="key=envs/<ENV>/terraform.tfstate"
  EOT
}
