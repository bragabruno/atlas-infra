###############################################################################
# INF-5 — AKS Module
#
# Provisions:
#   - AKS cluster with Azure CNI networking
#   - System node pool  (burstable SKU, fixed count)
#   - Workload node pool (burstable SKU, cluster-autoscaler enabled)
#   - OIDC issuer enabled       → required for Workload Identity federation
#   - Workload Identity enabled → allows pods to exchange K8s SA tokens for
#                                  Azure AD tokens without long-lived secrets
#   - Azure Key Vault Secrets Provider add-on (CSI driver)
#   - Azure RBAC for Kubernetes authorisation
#
# Consumes from network module:
#   - var.subnet_system_id    (azurerm_subnet.system.id)
#   - var.subnet_workload_id  (azurerm_subnet.workload.id)
#
# Outputs consumed by identity module:
#   - output.oidc_issuer_url
#   - output.cluster_name
#
# Dependency order (from README): network → aks → identity → …
###############################################################################

###############################################################################
# AKS Cluster
###############################################################################

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  dns_prefix         = var.dns_prefix
  kubernetes_version = var.kubernetes_version

  # -------------------------------------------------------------------------
  # OIDC Issuer + Workload Identity
  #
  # oidc_issuer_enabled:        Publishes a well-known OIDC discovery document
  #                             so Azure AD can verify tokens issued by the
  #                             cluster's API server.
  # workload_identity_enabled:  Injects the azure-workload-identity webhook;
  #                             annotated pods receive projected SA tokens that
  #                             can be exchanged for Azure AD access tokens via
  #                             federated credentials on a managed identity.
  # -------------------------------------------------------------------------
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # -------------------------------------------------------------------------
  # Azure RBAC for Kubernetes authorisation
  # azure_rbac_enabled lets Azure AD users/groups be granted roles on the
  # cluster via ARM role assignments — no local kubeconfig credentials needed.
  # -------------------------------------------------------------------------
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # -------------------------------------------------------------------------
  # Identity
  # SystemAssigned: AKS manages the control-plane identity automatically;
  # no manual service principal rotation required.
  # -------------------------------------------------------------------------
  identity {
    type = "SystemAssigned"
  }

  # -------------------------------------------------------------------------
  # System node pool
  #
  # only_critical_addons_enabled: Taints this pool so that only kube-system
  # (CoreDNS, metrics-server, CSI drivers, etc.) pods land here.
  # Atlas workloads run exclusively on the workload pool.
  # -------------------------------------------------------------------------
  default_node_pool {
    name    = var.system_node_pool_name
    vm_size = var.system_node_pool_vm_size

    # Fixed count — no autoscaler on system pool to keep control-plane stable
    node_count = var.system_node_pool_node_count

    os_disk_size_gb = var.system_node_pool_os_disk_size_gb
    vnet_subnet_id  = var.subnet_system_id

    only_critical_addons_enabled = true

    tags = var.tags
  }

  # -------------------------------------------------------------------------
  # Networking — Azure CNI
  # azure CNI assigns pod IPs from the subnet range (not an overlay),
  # which is required for private endpoint + Key Vault CSI integration.
  # -------------------------------------------------------------------------
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  # -------------------------------------------------------------------------
  # Add-ons
  # -------------------------------------------------------------------------

  # Key Vault Secrets Provider (Secrets Store CSI Driver)
  # secret_rotation_enabled: poll Key Vault for secret version changes so pods
  # pick up rotated secrets without redeployment (Atlas NFR2 requirement).
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = var.tags
}

###############################################################################
# Workload node pool
#
# Separate from the default_node_pool so it can use a different VM SKU,
# run cluster-autoscaler, and sit in the workload subnet.
###############################################################################

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = var.workload_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.workload_node_pool_vm_size

  # Cluster Autoscaler
  auto_scaling_enabled = true
  min_count            = var.workload_node_pool_min_count
  max_count            = var.workload_node_pool_max_count

  os_disk_size_gb = var.workload_node_pool_os_disk_size_gb
  vnet_subnet_id  = var.subnet_workload_id

  # Node labels/taints: none by default — Atlas services tolerate the pool
  # via namespace-scoped network policy, not taints.

  tags = var.tags
}
