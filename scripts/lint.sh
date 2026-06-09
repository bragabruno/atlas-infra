#!/usr/bin/env bash
# lint.sh — Gate 1a (IaC format + lint): Trunk owns terraform fmt + tflint
# (.trunk/trunk.yaml). The single lint entrypoint for dev and CI.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

require_cmd trunk "https://get.trunk.io"
# --ci in CI (machine output + caching); --no-progress for a clean local run.
trunk_flag="--no-progress"
[[ -n "${CI:-}" ]] && trunk_flag="--ci"
run "trunk check (terraform fmt + tflint)" trunk check --all "$trunk_flag"

log_ok "lint: all static checks passed"
