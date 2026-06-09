#!/usr/bin/env bash
# local.sh — local convenience: `terraform plan` for the dev env. Unlike
# test.sh (offline validate), a real plan needs the remote backend + Azure
# provider auth, so this skips cleanly when those are absent rather than
# prompting or failing. Configure with:
#   TF_BACKEND_RG / TF_BACKEND_SA   (remote state storage account)
#   az login                         (or OIDC env vars)
# TF_DIR overrides the env root (default infra/terraform/envs/dev).
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

require_cmd terraform "https://developer.hashicorp.com/terraform/install"
tf_dir="${TF_DIR:-infra/terraform/envs/dev}"

if [[ -z "${TF_BACKEND_RG:-}" || -z "${TF_BACKEND_SA:-}" ]]; then
  skip "terraform plan" "remote backend not configured (set TF_BACKEND_RG / TF_BACKEND_SA)"
  exit 0
fi
if has_cmd az && ! az account show >/dev/null 2>&1; then
  skip "terraform plan" "not authenticated to Azure (run 'az login')"
  exit 0
fi

run "terraform init (${tf_dir})" \
  terraform -chdir="$tf_dir" init -input=false -no-color \
  -backend-config="resource_group_name=${TF_BACKEND_RG}" \
  -backend-config="storage_account_name=${TF_BACKEND_SA}" \
  -backend-config="container_name=${TF_BACKEND_CONT:-tfstate}" \
  -backend-config="key=envs/dev/terraform.tfstate"

run "terraform plan (${tf_dir})" terraform -chdir="$tf_dir" plan -input=false -no-color
log_ok "terraform plan complete"
