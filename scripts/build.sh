#!/usr/bin/env bash
# build.sh — N/A for this repo: atlas-infra ships Terraform + Helm charts, not a
# buildable application artifact. Kept for build-system parity (same target set
# across all Atlas repos); always a clean no-op here.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

skip "build" "no application artifact in this repo (Terraform + Helm only)"
exit 0
