###############################################################################
# Network Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create all network resources."
  type        = string
}

variable "location" {
  description = "Azure region for all network resources."
  type        = string
}

# ---------------------------------------------------------------------------
# VNet / Address Space
# ---------------------------------------------------------------------------

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
  default     = "atlas-vnet"
}

variable "vnet_address_space" {
  description = <<-EOT
    CIDR block(s) for the Virtual Network address space.

    Atlas CIDR plan (documented here for visibility — change only with an ADR):
      VNet:     10.0.0.0/16   (65 536 addresses)
        system:   10.0.0.0/22  (1 024) — AKS system node pool
        workload: 10.0.4.0/22  (1 024) — AKS workload node pool
        data:     10.0.8.0/24  (256)   — PostgreSQL + Redis private endpoints
  EOT
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

variable "subnet_system_cidr" {
  description = "CIDR for the 'system' subnet (AKS system node pool). Default: 10.0.0.0/22."
  type        = string
  default     = "10.0.0.0/22"
}

variable "subnet_workload_cidr" {
  description = "CIDR for the 'workload' subnet (AKS workload node pool). Default: 10.0.4.0/22."
  type        = string
  default     = "10.0.4.0/22"
}

variable "subnet_data_cidr" {
  description = "CIDR for the 'data' subnet (PostgreSQL + Redis private endpoints). Default: 10.0.8.0/24."
  type        = string
  default     = "10.0.8.0/24"
}

# ---------------------------------------------------------------------------
# NSG / Access Control
# ---------------------------------------------------------------------------

variable "allowed_api_source_cidrs" {
  description = <<-EOT
    List of CIDR blocks allowed to reach the workload subnet on HTTPS (443).
    Typically the corporate egress IP(s) or an Azure Front Door service tag.
    Defaults to deny-all (empty list — you must supply at least one value).
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all network resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "network"
  }
}
