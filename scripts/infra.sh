#!/usr/bin/env bash
# infra.sh — platform-chart validation: `helm lint` + `helm template` every
# wrapper chart under platform/.
#   * helm lint     — the HARD gate (offline; fails the stage on a bad chart).
#   * helm template — best-effort deep render in a throwaway copy of the chart
#                     (the working tree is never polluted with charts/ or
#                     Chart.lock). It needs the upstream subcharts, so it is
#                     ADVISORY: skipped cleanly when deps can't be fetched
#                     (offline), and a render failure only warns. These wrapper
#                     charts are deployed with runtime --set injection (Workload
#                     Identity, Key Vault CSI), so an upstream subchart's strict
#                     values schema can reject the static overlay even though the
#                     chart is valid. Set ATLAS_INFRA_STRICT=1 to make a render
#                     failure fail the stage.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
# shellcheck source=scripts/lib/colors.sh
source scripts/lib/colors.sh
# shellcheck source=scripts/lib/common.sh
source scripts/lib/common.sh
trap 'on_err "$LINENO" "$?"' ERR

if [[ ! -d platform ]]; then
  skip "infra" "no platform/ charts in this repo"
  exit 0
fi
if ! has_cmd helm; then
  skip "helm lint" "helm not installed"
  exit 0
fi

infra_strict="${ATLAS_INFRA_STRICT:-0}"
render_failures=0

# These wrapper charts carry no default values.yaml — they require the env
# overlay (values-dev.yaml), which the Makefile deploy targets also pass. Both
# `helm lint` and `helm template` are given it so templates that read overlay
# keys (e.g. .Values.kafkaCluster.namespace) resolve.

# template_chart <chart-dir> — render in a throwaway copy so dependency build
# (which writes charts/ + Chart.lock) never touches the working tree. The
# env overlay is read from the copy (values-dev.yaml is copied in). Skips
# cleanly when the upstream subcharts cannot be fetched offline.
template_chart() {
  local chart="$1" name tmp
  name="$(basename "$chart")"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand tmp now so the trap cleans the right dir.
  trap "rm -rf '$tmp'" RETURN
  cp -R "$chart/." "$tmp/"
  if ! helm dependency build "$tmp" >/dev/null 2>&1 &&
     ! helm dependency update "$tmp" >/dev/null 2>&1; then
    skip "helm template ($name)" "upstream subcharts unavailable offline"
    return 0
  fi
  local vals=()
  [[ -f "$tmp/values-dev.yaml" ]] && vals=(-f "$tmp/values-dev.yaml")
  if run "helm template ($name)" helm template "$name" "$tmp" "${vals[@]}"; then
    return 0
  fi
  if [[ "$infra_strict" == "1" ]]; then
    render_failures=$((render_failures + 1))
  else
    log_warn "helm template ($name): render failed (advisory; deployed with --set injection — set ATLAS_INFRA_STRICT=1 to enforce)"
  fi
}

linted_any=0
for chart in platform/*/; do
  chart="${chart%/}"
  name="$(basename "$chart")"
  if [[ ! -f "$chart/Chart.yaml" ]]; then
    skip "helm ($name)" "not a Helm chart (no Chart.yaml)"
    continue
  fi
  linted_any=1
  vals=()
  [[ -f "$chart/values-dev.yaml" ]] && vals=(-f "$chart/values-dev.yaml")
  run "helm lint ($name)" helm lint "$chart" "${vals[@]}"
  template_chart "$chart"
done

if [[ "$linted_any" -eq 0 ]]; then
  skip "infra" "no Helm charts under platform/"
  exit 0
fi
if [[ "$render_failures" -gt 0 ]]; then
  log_error "infra: ${render_failures} chart(s) failed to render (strict mode)"
  exit 1
fi
log_ok "platform charts valid"
