#!/usr/bin/env bash
# compose.sh — validate the optional local offline dev-loop compose file
# (local/compose.dev.yaml — ADR-023 / INF-17). Runs `docker compose config` to
# parse, merge, and validate the file's structure; it pulls no images and
# starts no containers, so it is safe and fast in CI. Clean no-op where the
# compose file or the `docker compose` CLI is absent, so the same command is
# safe on any repo/host. See atlas-docs/07-build-system.md.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

compose_file="local/compose.dev.yaml"

if [[ ! -f "$compose_file" ]]; then
  skip "compose config" "no ${compose_file} in this repo"
  exit 0
fi

if ! has_cmd docker || ! docker compose version >/dev/null 2>&1; then
  skip "compose config" "docker compose CLI not available"
  exit 0
fi

run "compose config (${compose_file})" docker compose -f "$compose_file" config --quiet
log_ok "compose config valid"
