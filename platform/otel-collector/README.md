# platform/otel-collector — INF-13

Wrapper chart deploying two OpenTelemetry Collector instances (aliased from the
same upstream chart) that form the Atlas observability pipeline
(atlas-docs/04 §6.1):

```
AKS Pod (OTel SDK)
  └─ OTLP gRPC :4317 (loopback)
       └─ DaemonSet Collector  (per-node: receive → filter → batch → forward)
            └─ OTLP gRPC (intra-cluster)
                 └─ Gateway Collector  (Deployment: tail-sample → redact PII → export)
                      ├─ Splunk HEC  (traces + logs)
                      └─ OTLP HTTP   (metrics)
```

## Chart version

| Chart | Alias | Version | Released | App version | Repo |
|-------|-------|---------|----------|-------------|------|
| open-telemetry/opentelemetry-collector | `daemonset` | **0.156.2** | 2026-05-21 | OTel Collector Contrib 0.152.0 | https://open-telemetry.github.io/opentelemetry-helm-charts |
| open-telemetry/opentelemetry-collector | `gateway` | **0.156.2** | 2026-05-21 | OTel Collector Contrib 0.152.0 | https://open-telemetry.github.io/opentelemetry-helm-charts |

Both aliases pin the same upstream chart version.
Verified ≥ 14 days before the 2026-05-24 dependency floor.

## GenAI semantic conventions

`OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental` enables the
`gen_ai.*` span attribute namespace (per-model token counts, latency, finish
reasons, prompt template IDs). This env var must be set on **every Atlas
service pod** — not only on the collector. It is set on the collector itself
so its internal telemetry also adopts the latest convention.

See atlas-docs/04 §6.2 for the full attribute table.

## Splunk endpoint — Key Vault reference (no secrets in values)

Splunk credentials follow the same Key Vault CSI model used by every other
Atlas service (atlas-docs/04 §3 + README root §Workload Identity):

```
mi-atlas-otel-collector (Managed Identity)
  └─ Key Vault Secrets User (scoped to rg-atlas-secrets-<env>/kv-atlas-<env>)
       └─ SecretProviderClass: atlas-otel-splunk-spc
            ├─ splunk-hec-endpoint   → /mnt/secrets/splunk/splunk-hec-endpoint
            └─ splunk-hec-token      → /mnt/secrets/splunk/splunk-hec-token
```

The `SecretProviderClass` is provisioned by `infra/terraform/modules/secrets`.
The gateway collector pod mounts these via CSI and reads them as Kubernetes
`Secret` references (via the Secrets Store CSI `secretObjects` sync). No HEC
token appears in values files, ConfigMaps, or container images.

## PII redaction

The gateway pipeline includes the `redaction` processor (atlas-docs/04 §6.2
and §6.5) that strips the following attributes before export to Splunk:

| Attribute | Reason |
|-----------|--------|
| `gen_ai.prompt` | Raw user query text |
| `gen_ai.completion` | Raw LLM response text |
| `gen_ai.request.messages` | Full message array |
| `gen_ai.response.messages` | Full response messages |

The DaemonSet pipeline additionally drops health-check spans (`/healthz`,
`/readyz`) to reduce HEC ingestion volume.

## Install (dev)

```bash
# Add upstream repo
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Resolve dependencies
helm dependency update .

# Install (both DaemonSet + Gateway in one release)
helm upgrade --install atlas-otel-collector . \
  --namespace atlas-dev \
  --create-namespace \
  --values values-dev.yaml

# Verify DaemonSet pods (one per node)
kubectl get pods -n atlas-dev -l app.kubernetes.io/component=agent

# Verify Gateway Deployment pod
kubectl get pods -n atlas-dev -l app.kubernetes.io/component=standalone

# Tail gateway logs to confirm Splunk export
kubectl logs -n atlas-dev deploy/atlas-otel-collector-gateway-opentelemetry-collector -f
```

## No secrets

No Splunk token, endpoint, or any other credential appears in this chart.
The gateway collector references a Kubernetes `Secret` that is populated by the
Secrets Store CSI driver from Key Vault. The `SecretProviderClass`
`atlas-otel-splunk-spc` is managed by Terraform (secrets module).
