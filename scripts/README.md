# atlas-infra — build scripts

Single source of truth for build & validation. Developers and CI run the **same**
scripts; `make ci` (or `./scripts/ci.sh`) runs the full gate locally, and the
Bitbucket pipeline calls the same per-stage scripts. Cross-repo guide:
[atlas-docs/07-build-system.md](../../atlas-docs/07-build-system.md).

| Script | Make target | What it does |
|---|---|---|
| `lint.sh` | `make lint` | Trunk (terraform fmt + tflint) over all files |
| `test.sh` | `make test` | per-dir `terraform init -backend=false` + `validate` (modules + bootstrap + envs/dev) |
| `infra.sh` | `make infra` | `helm lint` + `helm template` every chart under `platform/` |
| `security.sh` | `make security` | Checkov + Trivy config + gitleaks (advisory; `ATLAS_SECURITY_STRICT=1`) |
| `coverage.sh` | `make coverage` | N/A (no unit-test suite) — clean skip |
| `build.sh` | `make build` | N/A (no application artifact) — clean skip |
| `docker.sh` | `make docker` | N/A (no Dockerfile) — clean skip |
| `ci.sh` | `make ci` | runs lint → test → infra → security, in order |
| `local.sh` | `make local` | `terraform plan` for the dev env (skips without backend + Azure auth) |

`lib/common.sh` + `lib/colors.sh` hold the shared helpers (logging, timing,
command checks, error trap) — copied verbatim from the atlas-gateway reference.
All scripts are bash with `set -Eeuo pipefail`, shellcheck-clean, idempotent, and
run on Linux + macOS. Stages that are N/A for this repo, or whose tools are
absent, print `↷ skip` and exit 0 — so the same command works on a laptop and in
CI. `infra.sh` renders charts in a throwaway copy, so `helm dependency build`
never pollutes the working tree.

The existing cloud-lifecycle targets (`full-up`, `cloud-up`, `tf-apply`,
`destroy`, …) are unchanged and live in the same `Makefile`; run `make help` to
see both the build-system and the deployment targets.
