###############################################################################
# AKS Module — Outputs
#
# Downstream modules consume these values:
#   identity module: oidc_issuer_url, cluster_name
###############################################################################

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster. Passed to the identity module to create federated credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity" {
  description = <<-EOT
    Kubelet identity object. Contains:
      client_id   — used to annotate Kubernetes ServiceAccounts
      object_id   — used for role assignments
      user_assigned_identity_id — ARM resource ID of the kubelet identity
  EOT
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0]
}

output "node_resource_group" {
  description = "Name of the auto-generated node resource group (MC_*) that holds VM scale sets, disks, and NICs."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster. Sensitive — use only for bootstrapping; prefer Azure RBAC for day-to-day access."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}
