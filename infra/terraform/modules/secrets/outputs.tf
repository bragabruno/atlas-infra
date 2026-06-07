###############################################################################
# Secrets Module — Outputs
#
# Downstream modules / Helm values consume these values:
#   data module:     key_vault_id (to scope Key Vault Secrets User role)
#   identity module: key_vault_id (role assignment scope)
#   Helm/kubectl:    secret_provider_class_yaml (apply to cluster)
###############################################################################

output "key_vault_id" {
  description = "ARM resource ID of the Key Vault. Pass to identity module role assignments as the scope for 'Key Vault Secrets User'."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault (e.g. https://<name>.vault.azure.net/). Used in SecretProviderClass keyvaultName parameter."
  value       = azurerm_key_vault.this.vault_uri
}

output "private_endpoint_ip" {
  description = "Private IP address of the Key Vault private endpoint NIC."
  value       = azurerm_private_endpoint.key_vault.private_service_connection[0].private_ip_address
}

output "private_dns_zone_id" {
  description = "Resource ID of the privatelink.vaultcore.azure.net private DNS zone."
  value       = azurerm_private_dns_zone.key_vault.id
}

output "secret_provider_class_yaml" {
  description = <<-EOT
    YAML template for a Kubernetes SecretProviderClass that mounts secrets from
    this Key Vault via the Secrets Store CSI driver.

    Apply this manifest to the cluster with:
      terraform output -raw secret_provider_class_yaml | kubectl apply -f -

    The template references secrets by name only — no values are embedded.
    Identity is established via Workload Identity (var.identity_client_id).

    Secrets in the 'objects' list correspond to var.secret_names; add entries
    there to expose additional secrets to the pod without changing Terraform code.
  EOT
  value       = <<-YAML
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      name: atlas-keyvault-spc
      namespace: ${var.kubernetes_namespace}
    spec:
      provider: azure
      parameters:
        usePodIdentity: "false"
        useVMManagedIdentity: "false"
        clientID: "${var.identity_client_id}"
        keyvaultName: "${azurerm_key_vault.this.name}"
        tenantId: "${var.tenant_id}"
        objects: |
          array:
    %{for secret_name in var.secret_names~}
            - |
              objectName: ${secret_name}
              objectType: secret
    %{endfor~}
      secretObjects: []
  YAML
}
