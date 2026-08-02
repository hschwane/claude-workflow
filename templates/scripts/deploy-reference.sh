#!/usr/bin/env bash
# Deploys the REFERENCE environment — the one that follows `develop`. git-flow only.
#
#   ./scripts/deploy-reference.sh
#
# Run after every merge into `develop`, so the reference environment always shows what develop
# actually contains. Two ways that happens, and the first is the default:
#
#   1. Claude runs this script locally; the merge commit keeps its `[skip ci]`.
#   2. Claude does not run it → the merge is pushed WITHOUT `[skip ci]` and .github/workflows/
#      reference-deploy.yml runs it. A workflow alone cannot be relied on: `[skip ci]` suppresses
#      EVERY workflow for that commit, not just CI, so a marked merge would silently stop the
#      reference environment tracking develop — with nothing reporting it.
#
# This is a SEPARATE SCRIPT, not `deploy.sh --env reference`, on purpose. A mistyped flag
# deploys to production; a mistyped script name fails to run. Read-only tools (healthcheck.sh)
# take --env; deploying tools never do.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# Fails open: with `dirname` off PATH the expansion is empty and `cd "/.."` succeeds.
[ -f scripts/deploy-reference.sh ] || { echo "✗ deploy-reference.sh: not in the repo root (cwd=$PWD)." >&2; exit 1; }

# --- how to fill this in ---------------------------------------------------------------
# REFERENCE_TARGET and PRODUCTION_TARGET name the two deploy targets — the service, project or
# host each one deploys to, exactly as docs/dev/deploy.md's environment table records them.
# They are compared below: if they are ever equal, this script refuses to run rather than
# deploying develop to production. Fill BOTH; leaving PRODUCTION_TARGET empty disables the
# one guard that makes this script safe to run unattended.
# Each `step` line is a COMMAND LINE, not a comment. Never append `|| true`.
# --- end of authoring notes; everything below is live code ------------------------------
REFERENCE_TARGET="{{REFERENCE_TARGET}}"
PRODUCTION_TARGET="{{PRODUCTION_TARGET}}"

if [ -z "$REFERENCE_TARGET" ] || [ -z "$PRODUCTION_TARGET" ]; then
  echo "✗ deploy-reference.sh: both REFERENCE_TARGET and PRODUCTION_TARGET must be set." >&2
  echo "  Without production's name there is nothing to compare against, and the guard below" >&2
  echo "  would pass by knowing nothing." >&2
  exit 1
fi
if [ "$REFERENCE_TARGET" = "$PRODUCTION_TARGET" ]; then
  echo "✗ deploy-reference.sh: the reference target is the production target ($REFERENCE_TARGET)." >&2
  echo "  Refusing to deploy develop to production. Reference must be a separate service with" >&2
  echo "  its own database, secrets and domain — see docs/dev/deploy.md." >&2
  exit 1
fi

STEPS=0
step() {
  STEPS=$((STEPS + 1))
  echo "  → $*"
  "$@"
  local code=$?
  [ "$code" -eq 0 ] && return 0
  echo "  ✗ FAILED (exit $code): $*" >&2
  echo "✗ deploy-reference.sh: failed at step $STEPS. Nothing after this point ran." >&2
  exit "$code"
}

echo "▶ deploy-reference.sh → $REFERENCE_TARGET"
# e.g. step railway up --service "$REFERENCE_TARGET" | step docker build … && step docker push …
{{DEPLOY_REFERENCE}}

if [ "$STEPS" -eq 0 ] && [ "${REFERENCE_ALLOW_EMPTY:-0}" != "1" ]; then
  echo "✗ deploy-reference.sh: no steps are configured — this deployed nothing." >&2
  echo "  If the platform tracks the develop branch by itself, there is genuinely nothing to" >&2
  echo "  run here: delete this script and the reference-deploy workflow instead of leaving a" >&2
  echo "  no-op that looks like it did something. Otherwise fill the steps." >&2
  exit 1
fi

echo "✓ deploy-reference.sh complete — $STEPS step(s). Verify with:"
echo "    scripts/healthcheck.sh --env reference"
