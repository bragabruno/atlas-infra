###############################################################################
# AKS Module — Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create all AKS resources."
  type        = string
}

variable "location" {
  description = "Azure region for all AKS resources."
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "atlas-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Must be a supported version in the target Azure region."
  type        = string
  default     = "1.30"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster. Used to form the cluster FQDN."
  type        = string
  default     = "atlas"
}

# ---------------------------------------------------------------------------
# Networking — subnet IDs consumed from the network module
# ---------------------------------------------------------------------------

variable "subnet_system_id" {
  description = "Resource ID of the 'system' subnet (from network module output subnet_system_id). Hosts the AKS system node pool."
  type        = string
}

variable "subnet_workload_id" {
  description = "Resource ID of the 'workload' subnet (from network module output subnet_workload_id). Hosts the AKS workload node pool."
  type        = string
}

# ---------------------------------------------------------------------------
# System node pool
# ---------------------------------------------------------------------------

variable "system_node_pool_name" {
  description = "Name for the system node pool. Must be lowercase alphanumeric, max 12 chars on Linux."
  type        = string
  default     = "system"
}

variable "system_node_pool_vm_size" {
  description = <<-EOT
    VM SKU for system node pool nodes.
    Dev default: Standard_B2s (2 vCPU / 4 GB, burstable — cost-optimised for non-prod).
    Upgrade to Standard_D4ds_v5 or similar for production workloads.
  EOT
  type        = string
  default     = "Standard_B2s"
}

variable "system_node_pool_node_count" {
  description = "Fixed node count for the system pool. System pool does not autoscale to keep kube-system workloads stable."
  type        = number
  default     = 1
}

variable "system_node_pool_os_disk_size_gb" {
  description = "OS disk size (GiB) for system pool nodes."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# Workload node pool
# ---------------------------------------------------------------------------

variable "workload_node_pool_name" {
  description = "Name for the workload node pool. Must be lowercase alphanumeric, max 12 chars on Linux."
  type        = string
  default     = "workload"
}

variable "workload_node_pool_vm_size" {
  description = <<-EOT
    VM SKU for workload node pool nodes.
    Dev default: Standard_B4ms (4 vCPU / 16 GB, burstable — cost-optimised for non-prod).
    Upgrade to Standard_D8ds_v5 or similar for production.
  EOT
  type        = string
  default     = "Standard_B4ms"
}

variable "workload_node_pool_min_count" {
  description = "Minimum node count for the workload pool autoscaler."
  type        = number
  default     = 1
}

variable "workload_node_pool_max_count" {
  description = "Maximum node count for the workload pool autoscaler."
  type        = number
  default     = 3
}

variable "workload_node_pool_os_disk_size_gb" {
  description = "OS disk size (GiB) for workload pool nodes."
  type        = number
  default     = 50
}

# ---------------------------------------------------------------------------
# Identity / RBAC
# ---------------------------------------------------------------------------

variable "admin_group_object_ids" {
  description = <<-EOT
    List of Azure AD group object IDs granted the 'Azure Kubernetes Service Cluster Admin Role'
    via AKS-managed Azure RBAC. Leave empty to disable Azure RBAC admin binding
    (not recommended for production).
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all AKS resources."
  type        = map(string)
  default = {
    project    = "atlas"
    managed-by = "terraform"
    module     = "aks"
  }
}
