variable "location" {
  description = "Azure region to create the state backend resources in."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the Terraform state backend resources."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique name for the Azure Storage account that stores Terraform state. Must be 3-24 lowercase alphanumeric characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase alphanumeric characters (no hyphens or underscores)."
  }
}

variable "container_name" {
  description = "Name of the blob container inside the storage account that holds state files."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags applied to all bootstrap resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform-bootstrap"
  }
}
