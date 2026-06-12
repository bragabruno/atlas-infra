# Local Offline Dev Loop (docker-compose)

Optional, zero-cost, offline dev loop per [ADR-023](../../atlas-docs/02-tech-stack-and-adrs.md).
It runs Atlas against **free local equivalents** of the paid services instead of
live Azure. The AKS dev loop ([§4.3](../../atlas-docs/04-infra-cicd-observability.md))
remains the default and the source of truth for infrastructure/security validation.

Full service→mock mapping, pinned images, and fidelity caveats:
[atlas-docs/research/local-mock-stack.md](../../atlas-docs/research/local-mock-stack.md).

## Usage

```bash
make local-up      # build + start the stack (detached)
make local-down    # stop and remove the stack + volumes
```

Requires Docker with the Compose plugin. Sibling repos (`atlas-gateway`,
`atlas-mcp-doc-search`, `atlas-mcp-citations`, `atlas-frontend`) must be checked
out next to `atlas-infra/` — the build contexts are `../../atlas-*`.

## What comes up

| Service | Host URL | Notes |
|---|---|---|
| gateway | http://localhost:8090 | `model=mock` (no provider keys); cache + rate-limit on Valkey (host 8090 — :8000 often taken by a local mcp-proxy) |
| mcp-doc-search | http://localhost:8081 | wired to OpenSearch + Qdrant + gateway (FastMCP `/mcp`) |
| mcp-citations | http://localhost:8082 | wired to OpenSearch + Qdrant (FastMCP `/mcp`) |
| agent-runtime | http://localhost:8083 | FastAPI trigger surface (AGT-16); persists runs to Postgres |
| frontend | http://localhost:8080 | see CORS caveat below |
| Qdrant | http://localhost:6333 | |
| OpenSearch | http://localhost:9200 | security plugin disabled (local only) |
| Postgres | localhost:5432 | `atlas`/`atlas`/`atlas` (local dev creds) |
| Valkey | localhost:6379 | |
| MLflow | http://localhost:5500 | SQLite backend (host 5500 — :5000 collides with macOS AirPlay) |
| Redpanda Console | http://localhost:8086 | Kafka UI — browse topics (e.g. `atlas.calls.v1`) |
| RedisInsight | http://localhost:5540 | Valkey UI — connect to host `valkey`, port `6379` |
| OpenObserve | http://localhost:5080 | OTLP sink on :5081 (Splunk substitute) |
| Azurite | localhost:10000-10002 | Blob/Queue/Table emulator |
| lowkey-vault | https://localhost:8443 | Key Vault test double |

## Known caveats / follow-ups

- **Frontend → gateway CORS (wired).** The SPA runs in the host browser and
  calls the gateway cross-origin at `http://localhost:8090` (set in
  `frontend-config.json`). The compose sets `ATLAS_CORS_ALLOW_ORIGINS` on the
  gateway to allow `http://localhost:8080` (the SPA's own origin, unchanged by
  the gateway host-port remap), so chat calls work with the gateway's
  config-gated CORS support.
- **`atlas-agent-runtime` is not included** — it has no HTTP surface yet
  (ADR-020's `POST /v1/agent/runs` is unimplemented). It joins the stack once
  that surface lands.
- **Not a security mirror.** No CMK, private endpoints, Workload Identity,
  TLS-only paths, or network ACLs. Validate those on the AKS dev loop.
