###############################################################################
# Identity Module — Outputs
#
# Downstream modules consume:
#   secrets module: identity_client_ids (annotate K8s ServiceAccounts via Helm)
#   Any module that needs to pass a managed identity client ID to a pod annotation
###############################################################################

output "identity_client_ids" {
  description = <<-EOT
    Map of service name → managed identity client ID.
    Kubernetes ServiceAccounts must be annotated with:
      azure.workload.identity/client-id: <client_id>
    to enable token federation.
  EOT
  value = {
    for svc_name, identity in azurerm_user_assigned_identity.service :
    svc_name => identity.client_id
  }
}

output "identity_principal_ids" {
  description = "Map of service name → managed identity principal ID (object ID in Azure AD)."
  value = {
    for svc_name, identity in azurerm_user_assigned_identity.service :
    svc_name => identity.principal_id
  }
}

output "identity_ids" {
  description = "Map of service name → managed identity ARM resource ID."
  value = {
    for svc_name, identity in azurerm_user_assigned_identity.service :
    svc_name => identity.id
  }
}
