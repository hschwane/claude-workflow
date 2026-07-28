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
VERSION="${1:?usage: release.sh <version>}"

echo "▶ release.sh $VERSION"

# 1. Gate — never release on a red suite.
"$(dirname "$0")/ci.sh" full

# --- how to fill this in ---------------------------------------------------------------
# Each step below is a `step <command>` line — a COMMAND LINE, not a comment. Replace the
# whole placeholder, keeping the `step ` prefix; DELETE the line for a step this project does
# not have. `step` counts what it runs, so a release that published nothing says so.
STEPS=0
step() {
  STEPS=$((STEPS + 1))
  echo "  → $*"
  "$@"
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

# 4. Deploy. This is the ONE step that may legitimately be a no-op: a platform that
# auto-deploys on merge (Railway, Vercel) genuinely has nothing to run here.
# e.g. step railway up | step : (Railway auto-deploys on merge)
step {{DEPLOY}}

# 5. Healthcheck — report so the caller can verify / roll back.
# This must be a REAL command. `docs/dev/deploy.md` carries the URL. A release that reports
# success having verified nothing is worse than one that stops: if the endpoint is genuinely
# unknown, put `exit 1` here with a TODO rather than a no-op.
# e.g. step curl -fsS https://<app>/health
step {{HEALTHCHECK}}

if [ "$STEPS" -eq 0 ] && [ "${RELEASE_ALLOW_EMPTY:-0}" != "1" ]; then
  echo "✗ release.sh $VERSION: no steps are configured — this released nothing." >&2
  echo "  Fill the steps in scripts/release.sh. If this project genuinely publishes and deploys" >&2
  echo "  nothing, record that in .claude/memory/tech-debt.md and set RELEASE_ALLOW_EMPTY=1." >&2
  exit 1
fi

echo "✓ release.sh $VERSION complete — $STEPS step(s)"
