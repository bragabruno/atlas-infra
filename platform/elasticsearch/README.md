# platform/elasticsearch — INF-12

Bitnami Elasticsearch Helm chart pinned for Atlas, with two index templates
applied post-install:

- `atlas-doc-corpus-*` — BM25 document retrieval (hybrid search with Qdrant)
- `atlas-logs-*` — structured OTel log index

## Chart version

| Chart | Version | Released | App version | Repo |
|-------|---------|----------|-------------|------|
| bitnami/elasticsearch | **22.1.7** | 2025-09-01 | Elasticsearch 9.1.2 | https://charts.bitnami.com/bitnami |

Verified ≥ 14 days before the 2026-05-24 dependency floor.

## Index templates

### `atlas-doc-corpus-*`

BM25 full-text index for the doc corpus retrieval leg of `atlas-mcp-doc-search`.
Paired with Qdrant `doc_chunks` for hybrid retrieval (atlas-docs/03 §6.1).

| Field | Type | Notes |
|-------|------|-------|
| `source_id` | keyword | Pre-filter by source document |
| `doc_id` | keyword | Atlas document record ID |
| `chunk_idx` | integer | Chunk position within doc |
| `text` | text (English analyzer) | BM25 scored field |
| `indexed_at` | date | Ingest timestamp |

Similarity: BM25 with k1=1.2, b=0.75 (ES defaults).

### `atlas-logs-*`

Structured log index following the OTel log data model.
Ingested by the OTel Collector log receiver (atlas-docs/04 §6).

| Field | Type | Notes |
|-------|------|-------|
| `@timestamp` | date | Log emission time |
| `severity_text` | keyword | TRACE/DEBUG/INFO/WARN/ERROR/FATAL |
| `body` | keyword | Log message (no PII search) |
| `service.name` | keyword | Emitting service |
| `trace_id` | keyword | Correlated OTel trace ID |
| `span_id` | keyword | Correlated OTel span ID |
| `attributes` | flattened | Structured metadata |

Retention is managed by an ILM policy (`atlas-logs-ilm`) applied separately
after cluster bootstrap. Hot: 90 days, cold: archive tier (matching atlas-docs/04 §6.5).

## Install (dev)

```bash
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install
helm upgrade --install atlas-elasticsearch . \
  --namespace atlas-dev \
  --create-namespace \
  --values values-dev.yaml

# Verify index templates after init Job completes
kubectl logs -n atlas-dev job/atlas-elasticsearch-atlas-elasticsearch-init

# Check templates applied
kubectl exec -n atlas-dev deploy/atlas-elasticsearch-master -- \
  curl -s http://localhost:9200/_index_template/atlas-doc-corpus | python3 -m json.tool
```

## No secrets

Security is disabled in dev (internal ClusterIP only). For production, enable
X-Pack security and pass credentials via Key Vault CSI mount
(`/mnt/secrets/elasticsearch-password`). Never set `security.elasticsearchPassword`
in values files.
