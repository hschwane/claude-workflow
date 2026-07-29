#!/usr/bin/env bash
# Canonical release/deploy entrypoint — the SINGLE source of truth for "how we ship".
# Run locally by /release (via the `runner` agent) by default; the GitHub release workflow
# calls the SAME script as a fallback (when local can't publish — missing creds / OIDC).
#
# The version bump + changelog are prepared by the main session BEFORE this runs (judgment).
# This script is the deterministic mechanical part: gate → build → publish → deploy.
#
#   ./scripts/release.sh <version>
#
# project-init / project-onboard fill in the real steps for this project's release type.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
# Fails open: with `dirname` off PATH, `cd "/.."` succeeds and this would release from /.
[ -f scripts/release.sh ] || { echo "✗ release.sh: not in the repo root (cwd=$PWD)." >&2; exit 1; }
VERSION="${1:?usage: release.sh <version>}"

echo "▶ release.sh $VERSION"

# 1. Gate — never release on a red suite.
"$(dirname "$0")/ci.sh" full

# --- how to fill this in ---------------------------------------------------------------
# Each step below is a `step <command>` line — a COMMAND LINE, not a comment. Replace the
# whole placeholder, keeping the `step ` prefix; DELETE the line for a step this project does
# not have. NEVER append `|| true` — `step` exits before the suffix is evaluated, so it cannot
# hide a failure, but writing it means the release stops with a confusing message instead of
# the real one. `step` counts what it runs, so a release that published nothing says so.
# --- end of authoring notes; everything below is live code ------------------------------
STEPS=0
FAILED=0
step() {
  STEPS=$((STEPS + 1))
  echo "  → $*"
  # Same shape as ci.sh's check(): capture the command's own status (never via an `if`
  # block, whose $? is 0), then EXIT rather than return — a `|| true` appended to the step
  # would otherwise swallow the failure and let a release that published and deployed
  # nothing report success.
  "$@"
  local code=$?
  [ "$code" -eq 0 ] && return 0
  FAILED=1
  echo "  ✗ FAILED (exit $code): $*" >&2
  echo "✗ release.sh $VERSION: failed at step $STEPS. Nothing after this point ran." >&2
  exit "$code"
}

# 2. Build the release artifact.
# ci.sh full above already ran this project's build stage, so this line is for an artifact the
# gate does not produce (a container image, a signed tarball). If the gate's build IS the
# artifact, delete this line rather than building twice.
# e.g. step docker build -t app:$VERSION . | step tar czf dist/app-$VERSION.tgz -C dist .
step {{BUILD_ARTIFACT}}

# 3. Publish (only where creds are present locally; otherwise this is the CI fallback's job).
# e.g. step npm publish | step twine upload dist/* | step gh release create v$VERSION --generate-notes
step {{PUBLISH}}

# 3b. Schema migrations, if this project has a database.
# Ordering is a real decision, not a detail: migrate BEFORE the deploy only when the change is
# backward-compatible with the running version (expand), and do the destructive half (contract)
# in a LATER release once nothing reads the old shape. A migration that breaks the currently
# running code turns a deploy into an outage. Record which half this release is in the
# changelog entry, and put the rollback for it in docs/dev/deploy.md.
# e.g. step npm run migrate:up | step uv run alembic upgrade head   (delete if no database)
step {{MIGRATIONS}}

# 4. Deploy. This is the ONE step that may legitimately be a no-op: a platform that
# auto-deploys on merge (Railway, Vercel) genuinely has nothing to run here.
#
# A project that publishes nothing and deploys nowhere (release-type: internal,
# deploy: none) can legitimately delete steps 2-4 and keep only the healthcheck —
# that one step is enough to satisfy the guard at the bottom. Do not delete the
# healthcheck to make the script shorter; it is what proves the release runs.
# e.g. step railway up | step : (Railway auto-deploys on merge)
step {{DEPLOY}}

# 5. Healthcheck — must ASSERT, not just run.
# `step curl -fsS https://<app>/health` proves the endpoint answered; it does not prove the
# NEW version is live. `step node dist/index.js --version` prints a version and discards it —
# a release of 9.9.9 that still reports 0.2.0 exits 0. Compare against "$VERSION":
#   step sh -c 'node dist/index.js --version | grep -q "$0"' "$VERSION"
#   step sh -c 'curl -fsS https://<app>/health | grep -q "\"version\":\"$0\""' "$VERSION"
# `docs/dev/deploy.md` carries the URL. If it is genuinely unknown, put `exit 1` here with a
# TODO rather than a no-op — a release that reports success having verified nothing is worse
# than one that stops.
step {{HEALTHCHECK}}

if [ "$STEPS" -eq 0 ] && [ "${RELEASE_ALLOW_EMPTY:-0}" != "1" ]; then
  echo "✗ release.sh $VERSION: no steps are configured — this released nothing." >&2
  echo "  Fill the steps in scripts/release.sh. If this project genuinely publishes and deploys" >&2
  echo "  nothing, record that in .claude/memory/tech-debt.md and set RELEASE_ALLOW_EMPTY=1." >&2
  exit 1
fi

echo "✓ release.sh $VERSION complete — $STEPS step(s)"
