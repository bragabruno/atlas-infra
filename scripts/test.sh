#!/usr/bin/env bash
# test.sh — Gate 1b (IaC correctness): per-dir `terraform init -backend=false` +
# `terraform validate` across every Terraform dir (modules + bootstrap +
# envs/dev). Offline: -backend=false skips backend init, so no Azure/state
# access and no secret/API spend. Mirrors the bitbucket validate gate.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

require_cmd terraform "https://developer.hashicorp.com/terraform/install"

validate_dir() {
  local d="$1"
  terraform -chdir="$d" init -backend=false -input=false -no-color >/dev/null
  terraform -chdir="$d" validate -no-color
}

validated_any=0
for d in infra/terraform/modules/* infra/terraform/bootstrap infra/terraform/envs/dev; do
  ls "$d"/*.tf >/dev/null 2>&1 || continue
  validated_any=1
  run "terraform validate ($d)" validate_dir "$d"
done

if [[ "$validated_any" -eq 0 ]]; then
  skip "test" "no Terraform dirs found under infra/terraform"
  exit 0
fi
log_ok "terraform validate passed for all dirs"
