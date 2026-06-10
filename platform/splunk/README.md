# Atlas Splunk Dashboards (POL-4)

Versioned Splunk Dashboard Studio definitions. Import via the Splunk UI
(**Dashboards → Create New Dashboard → Import JSON**) or via the REST API.

## Dashboards

| File | Title | Panels |
|------|-------|--------|
| `dashboards/atlas-overview.json` | Atlas LLM Gateway — Overview | Cost per model/app/day; p50/p95/p99 latency by route; semantic cache hit rate; guardrail trigger rates; agent loop-depth; eval score trends |

## Data sources

All panels read from OTel metrics forwarded to Splunk via the OTel Collector
Helm chart (`platform/otel-collector/`). The expected Splunk index is
`atlas_metrics`; eval score trends also read from `atlas_mlflow` (forwarded
from MLflow via HEC).

Key metric names:

| OTel metric | Panels |
|-------------|--------|
| `atlas.accounting.cost_usd` | Cost per model/app |
| `http.server.request.duration` | Latency p50/p95/p99 |
| `atlas.cache.semantic.hits/misses` | Cache hit rate |
| `atlas.guardrail.checks` | Guardrail trigger rates |
| `gen_ai.agent.iterations` | Agent loop-depth |

## Importing via REST API

```bash
curl -X POST \
  "https://<splunk-host>:8089/servicesNS/nobody/<app>/data/ui/views" \
  -H "Authorization: Bearer $SPLUNK_TOKEN" \
  -H "Content-Type: application/json" \
  -d @dashboards/atlas-overview.json
```

## Versioning

Dashboard files are JSON and live in version control alongside the infra.
To update a dashboard: edit the JSON, increment the implicit version in the
filename suffix when breaking changes are made, and re-import.
