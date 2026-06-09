###############################################################################
# Observability Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create the Log Analytics workspace."
  type        = string
}

variable "location" {
  description = "Azure region for the Log Analytics workspace."
  type        = string
}

variable "workspace_name" {
  description = "Name of the Log Analytics workspace."
  type        = string
  default     = "log-atlas"
}

variable "sku" {
  description = <<-EOT
    Log Analytics workspace SKU.
    Dev default: 'PerGB2018' (pay-per-GB; cheapest for low ingest volumes).
  EOT
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Data retention in days (30–730). Dev default: 30 (minimum billed retention)."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "tags" {
  description = "Tags applied to the Log Analytics workspace."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "observability"
  }
}
