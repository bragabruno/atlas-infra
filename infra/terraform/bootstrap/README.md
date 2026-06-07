# Bootstrap — Terraform State Backend (INF-3)

This module is a **one-time, operator-run** step that creates the Azure Storage
resources needed before any other Atlas Terraform module can use a remote backend.

It intentionally uses a **local** backend so that it can be applied before the
remote storage exists (the classic chicken-and-egg problem).

---

## Resources Created

| Resource | Purpose |
|---|---|
| `azurerm_resource_group` | Holds all state backend resources |
| `azurerm_storage_account` | Stores state blobs; TLS-only, soft-delete enabled |
| `azurerm_storage_container` (`tfstate`) | One container; environment state files are separated by blob key |

Locking is provided by **Azure Blob lease** — the `azurerm` backend acquires a
lease before any write operation. No external lock table is required.

---

## One-Time Bootstrap Workflow

```bash
# 1. Authenticate
az login   # or configure OIDC for CI

# 2. Run bootstrap (local state — OK for a one-time setup)
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — choose a globally unique storage_account_name

terraform init          # local backend, no -backend-config needed here
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 3. Copy the backend_config_hint from outputs, then wire downstream modules:
#    In each envs/{dev,prod} directory:
terraform init \
  -backend-config="resource_group_name=<rg>" \
  -backend-config="storage_account_name=<sa>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=envs/<env>/terraform.tfstate"
```

> **Never re-apply this module once the remote backend is in use.** Destroying
> the storage account would erase all environment state.

---

## Backend Block Template

The root `backend.tf` (at `infra/terraform/backend.tf`) contains a partial
`azurerm` backend block. Real values are supplied at `terraform init` time via
`-backend-config` flags so that no sensitive or environment-specific values are
committed to source control.

---

## Security Notes

- `shared_access_key_enabled = true` is required for the `azurerm` backend.
  Restrict access via Azure RBAC on the storage account instead of rotating SAS tokens.
- Soft-delete (30-day blob retention) protects against accidental state deletion.
- `allow_nested_items_to_be_public = false` prevents public blob access.
