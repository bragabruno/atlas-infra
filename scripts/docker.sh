#!/usr/bin/env bash
# docker.sh — N/A for this repo: atlas-infra builds no container image (no
# Dockerfile; it provisions infra and packages platform Helm charts that
# reference upstream images). Kept for build-system parity; clean no-op here.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

skip "docker build" "no Dockerfile in this repo (Terraform + Helm only)"
exit 0
