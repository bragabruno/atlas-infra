# platform/mlflow — INF-14

MLflow tracking server for Atlas eval runs, prompt-version experiments,
and Gate 2 baseline comparisons (atlas-docs/04 §6.3, ADR-008).

```
atlas-prompts CI (Gate 2)
  └─ MLflow Python SDK
       └─ MLflow Tracking Server (this chart, AKS)
            ├─ Backend store: Azure PostgreSQL Flexible Server (modules/data)
            └─ Artifact store: Azure Blob Storage "artifacts" container (modules/storage)
```

## Chart version

| Chart | Version | Released | App version | Repo |
|-------|---------|----------|-------------|------|
| community-charts/mlflow | **1.8.1** | 2025-12-07 | MLflow 3.7.0 | https://community-charts.github.io/helm-charts |

Verified ≥ 14 days before the 2026-05-24 dependency floor.

## Backend store — PostgreSQL Flexible Server (modules/data)

MLflow metadata (run IDs, metrics, params, tags, experiment definitions) is
stored in the PostgreSQL Flexible Server provisioned by
`infra/terraform/modules/data`.

| Terraform output | Value used | Purpose |
|-----------------|------------|---------|
| `modules.data.pg_fqdn` | host in PG URI | Connect string host |

**No credentials appear in this chart.** The connection URI is assembled from
Key Vault secrets at pod startup via the Secrets Store CSI driver:

```
mi-atlas-mlflow (Managed Identity)
  └─ Key Vault Secrets User
       └─ SecretProviderClass: atlas-mlflow-pg-spc
            └─ KV secret "mlflow-pg-uri"
                 └─ synced to K8s Secret atlas-mlflow-pg-uri key pg-uri
                      └─ env var MLFLOW_BACKEND_STORE_URI (in pod)
```

The PG URI format is:
`postgresql+psycopg2://<user>:<password>@<pg_fqdn>:5432/mlflow?sslmode=require`

Assemble this in Terraform and store as a single opaque Key Vault secret
(`mlflow-pg-uri`). This avoids exposing individual credentials in separate
env vars.

## Artifact store — Azure Blob Storage (modules/storage)

MLflow artifacts (eval outputs, judge results, golden-set snapshots, run
artefacts) are stored in the `artifacts` Blob container provisioned by
`infra/terraform/modules/storage`.

| Terraform output | Value used | Purpose |
|-----------------|------------|---------|
| `modules.storage.storage_account_name` | `AZURE_STORAGE_ACCOUNT` env var | Blob endpoint resolution |

Authentication is via **Workload Identity** — the `mi-atlas-mlflow` managed
identity holds the `Storage Blob Data Contributor` role on the `artifacts`
container (atlas-docs/04 §3.2). No connection string or access key is required.
`DefaultAzureCredential` in the MLflow Azure Blob driver picks up the federated
token automatically.

The storage account name is injected from Key Vault (not hard-coded here):

```
mi-atlas-mlflow
  └─ SecretProviderClass: atlas-mlflow-storage-spc
       └─ KV secret "mlflow-storage-account-name"
            └─ synced to K8s Secret atlas-mlflow-storage-secrets
                 └─ env var AZURE_STORAGE_ACCOUNT (in pod)
```

Artifact path: `wasbs://artifacts@<storage_account_name>.blob.core.windows.net/mlflow/`

## What MLflow tracks

| Entity | Detail |
|--------|--------|
| Eval runs | Gate 2 execution: golden-set version, scores, metric deltas |
| Judge scores | Per-question LLM-judge outputs (faithfulness, relevance, groundedness) |
| Prompt experiments | Each `prompts/**` PR creates a named experiment |
| Cost / latency | Token counts + model pricing logged as metrics |
| Baseline tagging | Promoted run tagged `baseline=true`; Gate 2 diffs against it |

Source: atlas-docs/04 §6.3.

## Install (dev)

```bash
# Add community-charts repo
helm repo add community-charts https://community-charts.github.io/helm-charts
helm repo update

# Resolve dependencies
helm dependency update .

# Install (assumes SecretProviderClasses are already provisioned by Terraform)
helm upgrade --install atlas-mlflow . \
  --namespace atlas-dev \
  --create-namespace \
  --values values-dev.yaml \
  --set mlflow.serviceAccount.annotations."azure\.workload\.identity/client-id"=<MI_CLIENT_ID>

# Port-forward the UI for local access (dev only)
kubectl port-forward -n atlas-dev svc/atlas-mlflow-mlflow 5000:5000
# Open: http://localhost:5000
```

## No secrets

No PostgreSQL password, connection string, storage account key, or any other
credential appears in this chart. All sensitive values are read at pod startup
from Key Vault via the Secrets Store CSI driver and the `mi-atlas-mlflow`
managed identity.
