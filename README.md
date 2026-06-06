# atlas-infra

Terraform infrastructure for **Atlas** on Azure. All resources are managed via the `azurerm` provider (pinned version). No secrets in code or images — ever.

---

## Terraform Module List & Dependency Order

```
network → aks → identity
                        ↘
                         secrets
                         data
                         storage
                         kafka
                         observability
```

| Module | Path | What it provisions |
|---|---|---|
| `network` | `infra/terraform/modules/network` | VNet, subnets (system / workload / data), NSGs |
| `aks` | `infra/terraform/modules/aks` | AKS cluster, system + workload node pools, OIDC issuer, Workload Identity |
| `identity` | `infra/terraform/modules/identity` | Per-service user-assigned managed identities, federated credentials, least-privilege role assignments |
| `secrets` | `infra/terraform/modules/secrets` | Azure Key Vault, Secrets Store CSI driver, SecretProviderClass |
| `data` | `infra/terraform/modules/data` | Azure Database for PostgreSQL Flexible Server, Redis Cache |
| `storage` | `infra/terraform/modules/storage` | Azure Blob containers (golden-sets / trace-archive / artifacts), ACR |
| `kafka` | `infra/terraform/modules/kafka` | Azure Event Hubs (Kafka endpoint) or Strimzi on AKS |
| `observability` | `infra/terraform/modules/observability` | OTel Collector, MLflow |

Environments under `envs/{dev,prod}` compose all modules in the above order.

---

## State Backend

Remote state is stored in **Azure Blob Storage** with lease-based locking (no external lock table required).

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "<rg>"
    storage_account_name = "<sa>"
    container_name       = "tfstate"
    key                  = "envs/<env>/terraform.tfstate"
  }
}
```

State is environment-scoped: `envs/dev` and `envs/prod` each hold their own state file.

---

## How to Apply (dev)

```bash
# Authenticate via OIDC (CI) or az login (local)
az login

cd envs/dev
terraform init \
  -backend-config="resource_group_name=<rg>" \
  -backend-config="storage_account_name=<sa>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=envs/dev/terraform.tfstate"

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — never commit real values

terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

CI authenticates to Azure via **OIDC federated credentials** — no long-lived service principal keys are stored anywhere.

---

## Workload Identity + Key Vault CSI Model

Atlas enforces **zero secrets in code or container images** (NFR2).

```
Pod (K8s ServiceAccount)
  └─ Workload Identity (OIDC federation)
       └─ User-Assigned Managed Identity (per service)
            └─ Key Vault RBAC role (least-privilege)
                 └─ Secrets Store CSI Driver
                      └─ SecretProviderClass
                           └─ Mounted volume in pod (in-memory tmpfs)
```

1. Each service gets its own managed identity — no shared credentials.
2. The Kubernetes ServiceAccount is annotated with the managed identity client ID.
3. AKS OIDC issuer federates the SA token to Azure AD.
4. The Secrets Store CSI driver (via SecretProviderClass) retrieves secrets from Key Vault and mounts them as files — they never appear in environment variables sourced from plaintext config maps or image layers.
5. Network policies restrict cross-namespace traffic so a compromised service cannot reach another service's Key Vault paths.

---

## No-Secrets Policy

- `.tfvars` files are gitignored; only `.tfvars.example` files (no real values) are committed.
- Key Vault references replace all plaintext secrets in config.
- CI uses OIDC — no `ARM_CLIENT_SECRET` or long-lived tokens.
- `git-secrets` / pre-commit hooks block accidental commits of credentials.
- Secrets are rotated via Key Vault versioning; pods pick up new versions without redeployment.

---

## Diagrams

| Diagram | Path |
|---|---|
| Azure resource topology | `docs/diagrams/azure-topology.md` |
| AKS deployment (pods, namespaces, sidecars) | `docs/diagrams/aks-deployment.puml` |
| Terraform module dependency graph | `docs/diagrams/tf-module-graph.md` |
| Identity / secrets / network security model | `docs/diagrams/network-security.md` |

---

## Related

- Atlas mono-repo: `../atlas-docs` (architecture decisions, ADRs, runbooks)
- [Azure Workload Identity docs](https://azure.github.io/azure-workload-identity/docs/)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [AKS OIDC Issuer](https://learn.microsoft.com/en-us/azure/aks/use-oidc-issuer)
- [azurerm Terraform provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
