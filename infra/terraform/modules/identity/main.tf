###############################################################################
# INF-6 — Identity Module
#
# Provisions per-service Workload Identity resources following the model
# documented in the README:
#
#   Pod (K8s ServiceAccount)
#     └─ Workload Identity (OIDC federation)
#          └─ User-Assigned Managed Identity (per service)
#               └─ Least-privilege role assignments (Key Vault / Blob / etc.)
#
# For each entry in var.services this module creates:
#   1. azurerm_user_assigned_identity        — one identity per service
#   2. azurerm_federated_identity_credential — binds the identity to the K8s
#                                              ServiceAccount via the AKS OIDC issuer
#   3. azurerm_role_assignment (0..N)        — least-privilege ARM roles
#
# Consumes from aks module:
#   - var.oidc_issuer_url  (azurerm_kubernetes_cluster.this.oidc_issuer_url)
#
# Dependency order (from README): network → aks → identity → …
###############################################################################

###############################################################################
# Local helpers
###############################################################################

locals {
  # Build a flat map of { "<service>:<role>:<scope>" → assignment object } so
  # for_each on role assignments is stable across plan/apply cycles regardless
  # of list ordering.
  #
  # Key format: "<service_name>|<role_definition_name>|<scope>"
  # This is unique per (service, role, scope) triple.
  role_assignment_entries = merge([
    for svc_name, svc_cfg in var.services : {
      for ra in svc_cfg.role_assignments :
      "${svc_name}|${ra.role_definition_name}|${ra.scope}" => {
        service_name         = svc_name
        role_definition_name = ra.role_definition_name
        scope                = ra.scope
      }
    }
  ]...)

  # Resolve per-service namespace: use service-level override if set, else fall
  # back to the module-level default.
  service_namespace = {
    for svc_name, svc_cfg in var.services :
    svc_name => (
      svc_cfg.kubernetes_namespace != "" ? svc_cfg.kubernetes_namespace : var.kubernetes_namespace
    )
  }
}

###############################################################################
# User-Assigned Managed Identities — one per service
###############################################################################

resource "azurerm_user_assigned_identity" "service" {
  for_each = var.services

  name                = "uami-atlas-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, { service = each.key })
}

###############################################################################
# Federated Identity Credentials
#
# Each credential authorises the Kubernetes ServiceAccount
# "system:serviceaccount:<namespace>:<service>" to exchange its projected
# token for an Azure AD access token on behalf of the managed identity.
#
# subject format (Workload Identity convention):
#   system:serviceaccount:<kubernetes_namespace>:<service_name>
###############################################################################

resource "azurerm_federated_identity_credential" "service" {
  for_each = var.services

  name                = "federated-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.service[each.key].id

  issuer  = var.oidc_issuer_url
  subject = "system:serviceaccount:${local.service_namespace[each.key]}:${each.key}"

  # audience must be "api://AzureADTokenExchange" for Workload Identity
  audience = ["api://AzureADTokenExchange"]
}

###############################################################################
# Role Assignments — least-privilege per service
#
# Each entry in var.services[*].role_assignments becomes one
# azurerm_role_assignment keyed on the stable composite key defined in locals.
###############################################################################

resource "azurerm_role_assignment" "service" {
  for_each = local.role_assignment_entries

  principal_id         = azurerm_user_assigned_identity.service[each.value.service_name].principal_id
  role_definition_name = each.value.role_definition_name
  scope                = each.value.scope

  # skip_service_principal_aad_check prevents a 10 s delay when the managed
  # identity principal has not yet propagated to Azure AD.
  skip_service_principal_aad_check = true
}
