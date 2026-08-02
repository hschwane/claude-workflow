#!/usr/bin/env bash
# Canonical health entrypoint — "is the thing we just released the thing that is now live?"
#
#   ./scripts/healthcheck.sh                      → production, liveness only
#   ./scripts/healthcheck.sh 1.4.0                → production, and assert 1.4.0 is live
#   ./scripts/healthcheck.sh 1.4.0 --env reference
#
# NOT only for deployed apps. The subject is whatever carries the version once released:
#   a service    → its /health endpoint
#   a package    → `npm view <pkg> version`, `pip index versions <pkg>`
#   a CLI/binary → the built artifact's own `--version`
# A project with genuinely nothing versioned to probe — an internal tool that publishes and
# deploys nowhere — sets HEALTH_ALLOW_EMPTY=1 and records why in tech-debt.md. That is the
# only case with no probes, and it is rare.
#
# Called after a release (once the deploy settles), after a reference deploy, and standalone —
# for a rollback decision, or any time someone asks "what is actually running right now?".
# That question is why liveness has no stored artifact anywhere in this workflow: a record
# saying "the release steps executed" can be true while the service is down. Re-running this
# is the answer.
#
# READ-ONLY, so it takes an --env argument. Deploying scripts never do: they are separate files
# per target, because a typo in a flag deploys to the wrong environment while a typo in a script
# name simply fails to run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# Fails open: with `dirname` off PATH the expansion is empty and `cd "/.."` succeeds.
[ -f scripts/healthcheck.sh ] || { echo "✗ healthcheck.sh: not in the repo root (cwd=$PWD)." >&2; exit 1; }

VERSION=""
ENVIRONMENT="production"
while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENVIRONMENT="${2:?--env needs a value}"; shift 2 ;;
    -*) echo "✗ healthcheck.sh: unknown option $1" >&2; exit 1 ;;
    *) VERSION="$1"; shift ;;
  esac
done

echo "▶ healthcheck.sh ($ENVIRONMENT${VERSION:+ · expecting $VERSION})"

# --- how to fill this in ---------------------------------------------------------------
# Each line below is a `probe <command>` — a COMMAND LINE, not a comment. Two rules, and the
# second is the one that matters:
#
#   * Never append `|| true`. `probe` exits before the suffix is evaluated, so it cannot hide
#     a failure — it just fails with a confusing message instead of the real one.
#   * A probe that only proves the endpoint ANSWERS is not a healthcheck. `curl -fsS /health`
#     returns 200 from the old version too; `node dist/index.js --version` prints a version and
#     throws it away, so a release of 9.9.9 still serving 0.2.0 exits 0. Compare against
#     "$VERSION" with `version_probe`:
#       version_probe sh -c 'curl -fsS https://app/health | grep -q "\"version\":\"$0\""' "$VERSION"
#       version_probe sh -c 'node dist/index.js --version | grep -q "$0"' "$VERSION"
#     When a version is passed, this script REFUSES to report healthy unless at least one
#     version_probe ran — otherwise "verified" would mean "something answered".
#
# URLs per environment belong in docs/dev/deploy.md's environment table; take them from there.
# --- end of authoring notes; everything below is live code ------------------------------
PROBES=0
VERSION_PROBES=0

probe() {
  PROBES=$((PROBES + 1))
  echo "  → $*"
  # Capture the command's own status — never via `if "$@"; then`, whose $? is the `if`'s (0).
  "$@"
  local code=$?
  [ "$code" -eq 0 ] && return 0
  echo "  ✗ UNHEALTHY (exit $code): $*" >&2
  echo "✗ healthcheck.sh ($ENVIRONMENT): probe $PROBES failed." >&2
  exit "$code"
}

# A probe that compares the live version against the expected one.
version_probe() {
  VERSION_PROBES=$((VERSION_PROBES + 1))
  probe "$@"
}

case "$ENVIRONMENT" in
  production)
    # e.g. version_probe sh -c 'curl -fsS https://app.example.com/health | grep -q "\"version\":\"$0\""' "$VERSION"
    {{HEALTHCHECK_PRODUCTION}}
    : # keeps this branch valid if the probe above is deleted — an empty branch is a syntax error
    ;;
  reference)
    # Only exists under branching: git-flow. Delete this whole branch in a main-only project.
    # e.g. version_probe sh -c 'curl -fsS https://app-reference.example.com/health | grep -q "$0"' "$VERSION"
    {{HEALTHCHECK_REFERENCE}}
    :
    ;;
  *)
    echo "✗ healthcheck.sh: unknown environment '$ENVIRONMENT' (see docs/dev/deploy.md)." >&2
    exit 1
    ;;
esac

if [ "$PROBES" -eq 0 ] && [ "${HEALTH_ALLOW_EMPTY:-0}" != "1" ]; then
  echo "✗ healthcheck.sh ($ENVIRONMENT): no probes are configured — this verified nothing." >&2
  echo "  Fill the probes in scripts/healthcheck.sh. If this environment genuinely cannot be" >&2
  echo "  probed, record that in .claude/memory/tech-debt.md and set HEALTH_ALLOW_EMPTY=1." >&2
  exit 1
fi

if [ -n "$VERSION" ] && [ "$VERSION_PROBES" -eq 0 ]; then
  echo "✗ healthcheck.sh ($ENVIRONMENT): asked to verify $VERSION, but no probe compares the" >&2
  echo "  live version against it. Reaching the service proves it answers, not that the new" >&2
  echo "  build is live — which is the whole question after a deploy. Add a version_probe." >&2
  exit 1
fi

echo "✓ healthcheck.sh ($ENVIRONMENT) healthy — $PROBES probe(s)${VERSION:+, version $VERSION confirmed}"
