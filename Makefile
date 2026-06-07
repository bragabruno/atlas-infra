# ---------------------------------------------------------------------------
# atlas-infra/Makefile
#
# Convenience targets for the Atlas dev and platform ops workflow.
# All targets require: kubectl, helm, az CLI, and (for dev loop) skaffold.
#
# Environment variables:
#   ENV         — "dev" or "prod" (default: dev)
#   NAMESPACE   — Kubernetes namespace (default: atlas-<ENV>)
#   KUBE_CTX    — kubectl context (default: atlas-<ENV>)
#   ACR_NAME    — ACR registry name (default: acratlas<ENV>)
# ---------------------------------------------------------------------------

ENV       ?= dev
NAMESPACE ?= atlas-$(ENV)
KUBE_CTX  ?= atlas-$(ENV)
ACR_NAME  ?= acratlas$(ENV)

.PHONY: help cloud-up cloud-down platform-up platform-down \
        otel-up otel-down mlflow-up mlflow-down \
        qdrant-up kafka-up es-up \
        context-check acr-login

# ---------------------------------------------------------------------------
# help — list available targets
# ---------------------------------------------------------------------------
help:
	@echo ""
	@echo "atlas-infra Makefile"
	@echo "ENV=$(ENV)  NAMESPACE=$(NAMESPACE)  KUBE_CTX=$(KUBE_CTX)"
	@echo ""
	@echo "Targets:"
	@echo "  cloud-up      Deploy all services (no local build; uses latest ACR images)"
	@echo "  cloud-down    Uninstall all Helm service releases from the namespace"
	@echo "  platform-up   Deploy all platform charts (Qdrant, Kafka, ES, OTel, MLflow)"
	@echo "  platform-down Uninstall all platform charts"
	@echo "  otel-up       Deploy OTel Collector chart only"
	@echo "  otel-down     Uninstall OTel Collector chart"
	@echo "  mlflow-up     Deploy MLflow chart only"
	@echo "  mlflow-down   Uninstall MLflow chart"
	@echo "  context-check Verify current kube-context matches ENV"
	@echo "  acr-login     az acr login for the ACR registry"
	@echo ""
	@echo "Dev loop (requires skaffold):"
	@echo "  skaffold dev --profile=$(ENV) --namespace=$(NAMESPACE)"
	@echo ""

# ---------------------------------------------------------------------------
# context-check — guard against deploying to wrong cluster
# ---------------------------------------------------------------------------
context-check:
	@CURRENT=$$(kubectl config current-context); \
	if [ "$$CURRENT" != "$(KUBE_CTX)" ]; then \
	  echo "ERROR: current context '$$CURRENT' != expected '$(KUBE_CTX)'."; \
	  echo "Run: kubectl config use-context $(KUBE_CTX)"; \
	  exit 1; \
	fi
	@echo "Context OK: $(KUBE_CTX)"

# ---------------------------------------------------------------------------
# acr-login — authenticate local Docker daemon to ACR
# ---------------------------------------------------------------------------
acr-login:
	az acr login --name $(ACR_NAME)

# ---------------------------------------------------------------------------
# cloud-up — deploy all Atlas services from published ACR images.
#            No local build. Equivalent to skaffold run without file-watching.
#            atlas-docs/04 §4.3: "make cloud-up ENV=dev deploys all services
#            from published ACR images without a local build."
# ---------------------------------------------------------------------------
cloud-up: context-check
	skaffold run \
	  --profile=$(ENV) \
	  --namespace=$(NAMESPACE) \
	  --kube-context=$(KUBE_CTX)
	@echo "All services deployed to $(NAMESPACE)."

# ---------------------------------------------------------------------------
# cloud-down — tear down all Atlas service releases
# ---------------------------------------------------------------------------
cloud-down: context-check
	skaffold delete \
	  --profile=$(ENV) \
	  --namespace=$(NAMESPACE) \
	  --kube-context=$(KUBE_CTX)
	@echo "All service releases removed from $(NAMESPACE)."

# ---------------------------------------------------------------------------
# platform-up — install all platform charts (Qdrant, Kafka, ES, OTel, MLflow)
# Run this once before cloud-up to ensure platform dependencies are ready.
# ---------------------------------------------------------------------------
platform-up: context-check qdrant-up kafka-up es-up otel-up mlflow-up
	@echo "All platform charts deployed to $(NAMESPACE)."

# ---------------------------------------------------------------------------
# platform-down — uninstall all platform charts
# ---------------------------------------------------------------------------
platform-down: context-check otel-down mlflow-down
	helm uninstall atlas-qdrant       -n $(NAMESPACE) --ignore-not-found
	helm uninstall atlas-kafka        -n $(NAMESPACE) --ignore-not-found
	helm uninstall atlas-elasticsearch -n $(NAMESPACE) --ignore-not-found
	@echo "All platform charts removed from $(NAMESPACE)."

# ---------------------------------------------------------------------------
# Individual platform chart targets
# ---------------------------------------------------------------------------
qdrant-up: context-check
	helm dependency update platform/qdrant
	helm upgrade --install atlas-qdrant platform/qdrant \
	  --namespace $(NAMESPACE) \
	  --create-namespace \
	  --values platform/qdrant/values-dev.yaml \
	  --kube-context $(KUBE_CTX)

kafka-up: context-check
	helm dependency update platform/kafka
	helm upgrade --install atlas-kafka platform/kafka \
	  --namespace $(NAMESPACE) \
	  --create-namespace \
	  --values platform/kafka/values-dev.yaml \
	  --kube-context $(KUBE_CTX)

es-up: context-check
	helm dependency update platform/elasticsearch
	helm upgrade --install atlas-elasticsearch platform/elasticsearch \
	  --namespace $(NAMESPACE) \
	  --create-namespace \
	  --values platform/elasticsearch/values-dev.yaml \
	  --kube-context $(KUBE_CTX)

otel-up: context-check
	helm dependency update platform/otel-collector
	helm upgrade --install atlas-otel-collector platform/otel-collector \
	  --namespace $(NAMESPACE) \
	  --create-namespace \
	  --values platform/otel-collector/values-dev.yaml \
	  --kube-context $(KUBE_CTX)

otel-down: context-check
	helm uninstall atlas-otel-collector -n $(NAMESPACE) --ignore-not-found

mlflow-up: context-check
	helm dependency update platform/mlflow
	helm upgrade --install atlas-mlflow platform/mlflow \
	  --namespace $(NAMESPACE) \
	  --create-namespace \
	  --values platform/mlflow/values-dev.yaml \
	  --kube-context $(KUBE_CTX)

mlflow-down: context-check
	helm uninstall atlas-mlflow -n $(NAMESPACE) --ignore-not-found
