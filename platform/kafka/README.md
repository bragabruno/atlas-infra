# platform/kafka — INF-11

Strimzi operator + KafkaTopic manifests for Atlas. Covers both deployment paths:

| Environment | Recommended | Notes |
|-------------|-------------|-------|
| dev | **Azure Event Hubs Kafka endpoint** | Zero ops; set `deployKafkaCluster=false` |
| prod | **Strimzi on AKS** | Full Kafka semantics; compaction, Kafka Streams, connectors |

## Chart version

| Chart | Version | Released | Repo |
|-------|---------|----------|------|
| strimzi/strimzi-kafka-operator | **1.0.0** | 2026-04-28 | https://strimzi.io/charts/ |

Verified ≥ 14 days before the 2026-05-24 dependency floor.

**Breaking change in 1.0.0:** only `v1` CRD API is supported. If upgrading from
Strimzi 0.x, migrate all CRs to `v1` before installing. See the
[Strimzi migration guide](https://strimzi.io/docs/operators/latest/full.html#assembly-upgrade-str).

## Topics

| Topic | Partitions (dev) | Retention | Partition key |
|-------|-----------------|-----------|---------------|
| `atlas.calls.v1` | 12 | 30 days | `api_key_id` |
| `atlas.spans.v1` | 6 | 7 days | `trace_id` |
| `atlas.shadow.v1` | 4 | 14 days | `alias` |
| `atlas.eval.requests.v1` | 4 | 7 days | `prompt_version_id` |

Source: atlas-docs/03 §4.

## Install (dev — Strimzi path)

```bash
# Add Strimzi Helm repo
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install operator + KafkaTopic manifests
helm upgrade --install atlas-kafka . \
  --namespace atlas-dev \
  --create-namespace \
  --values values-dev.yaml

# Verify operator pod
kubectl get pods -n atlas-dev -l strimzi.io/kind=cluster-operator

# Verify topics
kubectl get kafkatopics -n atlas-dev
```

## Install (dev — Event Hubs path)

```bash
# Skip cluster deployment; only install Strimzi operator for KafkaTopic management.
# Provision Event Hubs namespace + topics via the Terraform kafka module
# (infra/terraform/modules/kafka).

helm upgrade --install atlas-kafka . \
  --namespace atlas-dev \
  --create-namespace \
  --values values-dev.yaml \
  --set deployKafkaCluster=false
```

Event Hubs connection strings are never stored in this chart. They are injected
at runtime via Key Vault CSI mount (`/mnt/secrets/kafka-connection-string`).

## No secrets

This chart contains no credentials. Kafka broker address and any SASL/TLS config
for Event Hubs is injected via Key Vault CSI into each consuming service.
