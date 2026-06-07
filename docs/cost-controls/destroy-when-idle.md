# Destroy-When-Idle Runbook

**Scope:** Atlas dev environment (`ENV=dev`)
**Goal:** Eliminate all Azure compute costs when the dev cluster is not in use.
**Prerequisite:** `terraform.tfvars` populated; remote state backend accessible.

---

## When to use this runbook

Use **destroy** (not just scale-down) when:

- The dev cluster will be idle for more than a day (e.g. weekends, sprints paused).
- Cost budget alert fires above the monthly dev ceiling.
- You are switching Azure subscriptions or regions.

For **overnight** idle periods, prefer the scale-to-zero CronJob
(`platform/cost-controls/scale-to-zero-cronjob.yaml`), which keeps the cluster
alive and restores it in the morning — recreating the cluster takes ~10 minutes
via `make full-up`.

---

## Decision: scale-to-zero vs destroy

| Scenario | Recommended action | Bring-up time |
|---|---|---|
| Overnight (weekdays) | Scale-to-zero CronJob | ~3 min (nodes provision) |
| Weekend / multi-day idle | `make destroy ENV=dev` | ~10–15 min (full recreate) |
| Cost alert fires | `make destroy ENV=dev` | ~10–15 min (full recreate) |
| Subscription change | `make destroy ENV=dev` | ~10–15 min (full recreate) |

---

## Pre-destroy checklist

Run through these before destroying:

- [ ] No active CI pipelines targeting the dev cluster (check Bitbucket Pipelines).
- [ ] No long-running eval jobs in flight (`kubectl get jobs -n atlas-dev`).
- [ ] MLflow experiment runs are complete and results committed to the remote
      tracking URI (Terraform-managed PostgreSQL is destroyed with the cluster;
      local in-cluster state is lost).
- [ ] Any manual Key Vault secrets that were added out-of-band are documented
      or backed up — secrets are soft-deleted (90-day retention) and recoverable,
      but the procedure should be noted.
- [ ] Team members are aware the dev cluster is going down.

---

## Destroy procedure

```bash
# 1. Authenticate to Azure
az login
# Or if using OIDC in CI: env vars AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_FEDERATED_TOKEN_FILE

# 2. Set the Terraform backend variables (match your bootstrap output)
export TF_BACKEND_RG=rg-atlas-tfstate
export TF_BACKEND_SA=<storage-account-name>   # from bootstrap output

# 3. One-command destroy (services + platform + Terraform)
#    make destroy = cloud-down + platform-down + terraform destroy
make destroy ENV=dev \
  TF_BACKEND_RG=$TF_BACKEND_RG \
  TF_BACKEND_SA=$TF_BACKEND_SA

# Expected output:
#   All service releases removed from atlas-dev.
#   All platform charts removed from atlas-dev.
#   WARNING: This will destroy ALL dev Azure resources.
#   ... (5-second pause) ...
#   <terraform destroy output — ~10-15 min>
#   All dev resources destroyed.
```

If you want to destroy only the Azure resources (skipping Helm cleanup because
the cluster is already gone):

```bash
make tf-destroy ENV=dev \
  TF_BACKEND_RG=$TF_BACKEND_RG \
  TF_BACKEND_SA=$TF_BACKEND_SA
```

---

## Post-destroy verification

```bash
# Confirm the resource group is empty (or deleted)
az resource list --resource-group atlas-dev-rg --output table

# Confirm Terraform state shows no managed resources
terraform -chdir=infra/terraform/envs/dev show
```

Expected: empty resource list / `No state.` output.

---

## Recreate procedure

```bash
# 1. Authenticate
az login

# 2. Ensure terraform.tfvars is present and correct
#    (gitignored; copy from terraform.tfvars.example and fill in placeholders)
ls infra/terraform/envs/dev/terraform.tfvars

# 3. One-command bring-up
make full-up ENV=dev \
  TF_BACKEND_RG=$TF_BACKEND_RG \
  TF_BACKEND_SA=$TF_BACKEND_SA

# full-up = tf-apply + platform-up + cloud-up
# Estimated time: 10-15 min (AKS creation dominates)
```

After `full-up`:

1. `kubectl get nodes` — confirm system and workload nodes are Ready.
2. `kubectl get pods -n atlas-dev` — confirm all pods are Running.
3. `terraform -chdir=infra/terraform/envs/dev output acr_login_server` — confirm ACR FQDN.
4. Run a smoke test against the gateway health endpoint.

---

## Key Vault secret recovery

Secrets are soft-deleted with a 90-day retention window. If a Key Vault is
destroyed and recreated with the same name, existing soft-deleted secrets must
be recovered before the new vault can use them:

```bash
# List soft-deleted secrets
az keyvault secret list-deleted --vault-name <kv-name>

# Recover a specific secret
az keyvault secret recover --vault-name <kv-name> --name atlas-pg-password
```

If the Key Vault name changes (e.g. unique suffix differs), create the secrets
from scratch via the secure credential store:

```bash
az keyvault secret set \
  --vault-name <kv-name> \
  --name atlas-pg-password \
  --value "$(cat /path/to/secure/pg-password)"
```

Never store the secret value in a file committed to git. Use a password manager
or Azure Key Vault itself as the source of truth.

---

## Automated idle detection (future)

A nightly CI job (`nightly-cost-check` in `bitbucket-pipelines.yml`) can
automate destroy if the cluster has been idle for N hours:

```bash
# Illustrative — not yet implemented
IDLE_HOURS=8
LAST_DEPLOY=$(kubectl get events -n atlas-dev \
  --sort-by='.lastTimestamp' -o jsonpath='{.items[-1].lastTimestamp}')
AGE_HOURS=$(( ($(date +%s) - $(date -d "$LAST_DEPLOY" +%s)) / 3600 ))
if [ "$AGE_HOURS" -gt "$IDLE_HOURS" ]; then
  make destroy ENV=dev TF_BACKEND_RG=... TF_BACKEND_SA=...
fi
```

---

## Cost reference (westeurope, approximate)

| Resource | Dev SKU | Hourly cost | Monthly (730 h) |
|---|---|---|---|
| AKS system node (Standard_B2s) | 1 node | ~$0.04 | ~$29 |
| AKS workload node (Standard_B4ms) | 1 node | ~$0.17 | ~$124 |
| PostgreSQL (B_Standard_B1ms) | Always-on | ~$0.02 | ~$15 |
| Redis (Basic C0) | Always-on | ~$0.017 | ~$12 |
| ACR (Premium) | Always-on | ~$0.667/day | ~$20 |
| Key Vault | Per-operation | negligible | < $1 |
| Blob Storage (LRS) | Per-GB | negligible | < $1 |

**Estimated dev cost at full scale:** ~$200/month
**With nightly scale-to-zero (12 h/day, 5 d/week):** ~$95/month
**With weekend destroy (5 d/week, 12 h/day only):** ~$70/month

Numbers are approximate; verify against the Azure Pricing Calculator for your
exact region, reserved-instance discounts, and negotiated rates.
