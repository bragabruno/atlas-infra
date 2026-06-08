#!/usr/bin/env bash
# coverage.sh — N/A for this repo: there is no application unit-test suite to
# measure coverage for (test.sh runs `terraform validate`, not code tests).
# Kept for build-system parity; always a clean no-op here.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

skip "coverage" "no unit-test suite to measure (IaC validate only)"
exit 0
