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
#
# INF-16 additions (Terraform):
#   TF_DIR          — Terraform env root (default: infra/terraform/envs/<ENV>)
#   TF_BACKEND_RG   — Resource group holding the Terraform state storage account
#   TF_BACKEND_SA   — Storage account name for Terraform state
#   TF_BACKEND_CONT — State container name (default: tfstate)
#   TF_VARS_FILE    — Path to .tfvars file (default: <TF_DIR>/terraform.tfvars)
# ---------------------------------------------------------------------------

ENV       ?= dev
NAMESPACE ?= atlas-$(ENV)
KUBE_CTX  ?= atlas-$(ENV)
ACR_NAME  ?= acratlas$(ENV)

# INF-16: Terraform settings
TF_DIR          ?= infra/terraform/envs/$(ENV)
TF_BACKEND_RG   ?=
TF_BACKEND_SA   ?=
TF_BACKEND_CONT ?= tfstate
TF_VARS_FILE    ?= $(TF_DIR)/terraform.tfvars

.PHONY: help \
        lint test infra security build coverage docker ci local \
        tf-init tf-plan tf-apply tf-destroy \
        full-up full-down destroy \
        cloud-up cloud-down platform-up platform-down \
        otel-up otel-down mlflow-up mlflow-down \
        qdrant-up kafka-up es-up local-up local-down \
        context-check acr-login

# ---------------------------------------------------------------------------
# help — list available targets
# ---------------------------------------------------------------------------
help:
	@echo ""
	@echo "atlas-infra Makefile"
	@echo "ENV=$(ENV)  NAMESPACE=$(NAMESPACE)  KUBE_CTX=$(KUBE_CTX)"
	@echo "TF_DIR=$(TF_DIR)"
	@echo ""
	@echo "One-command lifecycle (INF-16):"
	@echo "  full-up  ENV=dev   terraform apply + platform helm + skaffold run"
	@echo "  full-down ENV=dev  skaffold delete + platform helm uninstall"
	@echo "  destroy  ENV=dev   full-down then terraform destroy (destructive!)"
	@echo ""
	@echo "Terraform targets:"
	@echo "  tf-init      terraform init (requires TF_BACKEND_RG / TF_BACKEND_SA)"
	@echo "  tf-plan      terraform plan -var-file=\$$TF_VARS_FILE"
	@echo "  tf-apply     terraform apply -var-file=\$$TF_VARS_FILE"
	@echo "  tf-destroy   terraform destroy (destructive!)"
	@echo ""
	@echo "Platform / service targets:"
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
	@echo "Build system (single source of truth — logic in scripts/):"
	@echo "  lint       Trunk (terraform fmt + tflint)"
	@echo "  test       per-dir terraform init -backend=false + validate"
	@echo "  infra      helm lint + template every platform/ chart"
	@echo "  security   Checkov + Trivy + gitleaks (advisory; ATLAS_SECURITY_STRICT=1)"
	@echo "  build      N/A (no app artifact) — clean skip"
	@echo "  coverage   N/A (no unit-test suite) — clean skip"
	@echo "  docker     N/A (no Dockerfile) — clean skip"
	@echo "  ci         lint -> test -> infra -> security (what CI runs)"
	@echo "  local      terraform plan for the dev env (needs backend + az login)"
	@echo ""

# ===========================================================================
# Build system — single source of truth (logic lives in scripts/, not here).
# Developers and CI run the same targets. See scripts/README.md and
# atlas-docs/07-build-system.md.
# ===========================================================================

lint: ## Trunk (terraform fmt + tflint)
	@./scripts/lint.sh

test: ## Per-dir terraform init -backend=false + validate
	@./scripts/test.sh

infra: ## helm lint + template every platform/ chart
	@./scripts/infra.sh

security: ## Checkov + Trivy + gitleaks (advisory; ATLAS_SECURITY_STRICT=1)
	@./scripts/security.sh

build: ## N/A (no application artifact) — clean skip
	@./scripts/build.sh

coverage: ## N/A (no unit-test suite) — clean skip
	@./scripts/coverage.sh

docker: ## N/A (no Dockerfile) — clean skip
	@./scripts/docker.sh

ci: ## Run the full build gate — what CI runs
	@./scripts/ci.sh

local: ## terraform plan for the dev env (needs backend + az login)
	@./scripts/local.sh

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

# ===========================================================================
# INF-16 — Terraform lifecycle targets
# ===========================================================================

# ---------------------------------------------------------------------------
# tf-guard — validate that required backend vars are set before terraform init
# ---------------------------------------------------------------------------
tf-guard:
	@if [ -z "$(TF_BACKEND_RG)" ] || [ -z "$(TF_BACKEND_SA)" ]; then \
	  echo "ERROR: TF_BACKEND_RG and TF_BACKEND_SA must be set."; \
	  echo "  make tf-init TF_BACKEND_RG=<rg> TF_BACKEND_SA=<sa>"; \
	  exit 1; \
	fi

# ---------------------------------------------------------------------------
# tf-init — initialise Terraform with the remote backend
#
# Requires TF_BACKEND_RG and TF_BACKEND_SA to be set.
# The state key is always scoped to envs/<ENV>/terraform.tfstate.
#
# Usage:
#   make tf-init ENV=dev TF_BACKEND_RG=rg-atlas-tfstate TF_BACKEND_SA=atlastfstateXXX
# ---------------------------------------------------------------------------
tf-init: tf-guard
	terraform -chdir=$(TF_DIR) init \
	  -backend-config="resource_group_name=$(TF_BACKEND_RG)" \
	  -backend-config="storage_account_name=$(TF_BACKEND_SA)" \
	  -backend-config="container_name=$(TF_BACKEND_CONT)" \
	  -backend-config="key=envs/$(ENV)/terraform.tfstate"
	@echo "Terraform initialised for $(TF_DIR)."

# ---------------------------------------------------------------------------
# tf-plan — show what Terraform would create/change/destroy
#
# Requires terraform.tfvars at TF_VARS_FILE (gitignored; copied from .example).
# ---------------------------------------------------------------------------
tf-plan:
	@test -f "$(TF_VARS_FILE)" || \
	  (echo "ERROR: $(TF_VARS_FILE) not found. Copy terraform.tfvars.example and fill in values." && exit 1)
	terraform -chdir=$(TF_DIR) plan -var-file="../../$(TF_VARS_FILE)"

# ---------------------------------------------------------------------------
# tf-apply — create or update all Azure resources for the environment
#
# NOTE: Azure resources cost money while running.  See docs/cost-controls/
# for the scale-to-zero CronJob and destroy-when-idle runbook.
# ---------------------------------------------------------------------------
tf-apply:
	@test -f "$(TF_VARS_FILE)" || \
	  (echo "ERROR: $(TF_VARS_FILE) not found. Copy terraform.tfvars.example and fill in values." && exit 1)
	terraform -chdir=$(TF_DIR) apply -var-file="../../$(TF_VARS_FILE)"
	@echo "Terraform apply complete for ENV=$(ENV)."

# ---------------------------------------------------------------------------
# tf-destroy — PERMANENTLY delete all Azure resources for the environment.
#
# This is the end-of-day / idle-cluster cost-control operation.
# State is preserved in the remote backend; re-run tf-apply to recreate.
# See docs/cost-controls/destroy-when-idle.md for the full runbook.
# ---------------------------------------------------------------------------
tf-destroy:
	@echo "WARNING: This will destroy ALL $(ENV) Azure resources."
	@echo "State is preserved; re-run 'make tf-apply ENV=$(ENV)' to recreate."
	@echo "Press Ctrl-C to abort.  Proceeding in 5 seconds..."
	@sleep 5
	terraform -chdir=$(TF_DIR) destroy -var-file="../../$(TF_VARS_FILE)"
	@echo "All $(ENV) resources destroyed."

# ---------------------------------------------------------------------------
# full-up — one command from zero to running dev cluster (INF-16)
#
# Steps:
#   1. terraform apply  — provision all Azure resources (network → aks →
#                          identity → secrets/data/storage)
#   2. platform-up      — install Qdrant, Kafka, ES, OTel Collector, MLflow
#   3. cloud-up         — deploy Atlas service images via Skaffold + Helm
#
# Prerequisites:
#   - az login (or OIDC env vars set)
#   - kubectl context atlas-<ENV> exists after tf-apply writes the kubeconfig
#   - TF_VARS_FILE populated (see terraform.tfvars.example)
#   - TF_BACKEND_RG / TF_BACKEND_SA set if using remote backend
#
# Usage:
#   make full-up ENV=dev
# ---------------------------------------------------------------------------
full-up: tf-apply context-check platform-up cloud-up
	@echo ""
	@echo "Atlas $(ENV) is up."
	@echo "  Namespace : $(NAMESPACE)"
	@echo "  Context   : $(KUBE_CTX)"
	@echo ""

# ---------------------------------------------------------------------------
# full-down — tear down services and platform charts without destroying Azure
#             resources (keeps the cluster so bring-up is faster next time)
#
# Usage:
#   make full-down ENV=dev
# ---------------------------------------------------------------------------
full-down: context-check cloud-down platform-down
	@echo "Atlas $(ENV) services and platform charts removed."
	@echo "Azure resources are still running (run 'make destroy ENV=$(ENV)' to remove them)."

# ---------------------------------------------------------------------------
# destroy — full tear-down: services + platform + Terraform destroy
#
# Use this at end of day or when the dev cluster is idle to eliminate costs.
# The Terraform state is preserved; re-run 'make full-up ENV=$(ENV)' to
# recreate from scratch.  See docs/cost-controls/destroy-when-idle.md.
#
# Usage:
#   make destroy ENV=dev
# ---------------------------------------------------------------------------
destroy: context-check cloud-down platform-down tf-destroy
	@echo "Atlas $(ENV) fully destroyed (Terraform state preserved)."

# ===========================================================================
# Service / platform deployment targets (pre-existing INF-15, unchanged)
# ===========================================================================

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
	helm uninstall atlas-qdrant        -n $(NAMESPACE) --ignore-not-found
	helm uninstall atlas-kafka         -n $(NAMESPACE) --ignore-not-found
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

# ---------------------------------------------------------------------------
# local-up / local-down — optional offline docker-compose dev loop (ADR-023)
# Free local equivalents for paid services; no Azure/kube context needed.
# See local/README.md and atlas-docs/research/local-mock-stack.md.
# ---------------------------------------------------------------------------
local-up: ## start the offline docker-compose dev loop (build + detached)
	docker compose -f local/compose.dev.yaml up --build -d

local-down: ## stop the offline dev loop and remove its volumes
	docker compose -f local/compose.dev.yaml down -v
