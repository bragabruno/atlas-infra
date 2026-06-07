# platform/qdrant — INF-10

Wrapper Helm chart that pins the upstream Qdrant chart and bootstraps the two
collections required by Atlas (atlas-docs/03 §3).

## Chart version

| Chart | Version | Released | Repo |
|-------|---------|----------|------|
| qdrant/qdrant | **1.18.0** | 2026-05-11 | https://qdrant.github.io/qdrant-helm |

Verified ≥ 14 days before the 2026-05-24 dependency floor.

## Collections created by the init Job

| Collection | Dim | Distance | HNSW m | HNSW ef_construct | TTL |
|------------|-----|----------|--------|-------------------|-----|
| `doc_chunks` | `qdrantVectorDim` (default 1536) | Cosine | 16 | 100 | none |
| `semantic_cache` | same | Cosine | 16 | 100 | 24 h |

Vector dimension is set at install time via `--set qdrantVectorDim=<dim>`.
Pin the value once the embedding model alias is finalised (atlas-docs/03 §3.1
states "TBD at build time").

## Install (dev)

```bash
# Add upstream repo
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo update

# Install (dev namespace)
helm upgrade --install atlas-qdrant . \
  --namespace atlas-dev \
  --create-namespace \
  --values values-dev.yaml \
  --set qdrantVectorDim=1536 \
  --version 0.1.0

# Verify collections after the init Job completes
kubectl logs -n atlas-dev job/atlas-qdrant-atlas-qdrant-init
```

## No secrets

Qdrant in dev runs unauthenticated (internal-only ClusterIP service).
Production should enable API key auth via Key Vault CSI mount
(`qdrant.config.service.api_key` from `/mnt/secrets/qdrant-api-key`).
