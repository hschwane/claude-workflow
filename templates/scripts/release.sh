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

# 2. Build the release artifact.
# {{BUILD_ARTIFACT}}   e.g. npm run build | docker build -t app:$VERSION . | cargo build --release

# 3. Publish (only where creds are present locally; otherwise this is the CI fallback's job).
# {{PUBLISH}}          e.g. npm publish | twine upload dist/* | docker push app:$VERSION
#                           | gh release create v$VERSION ...

# 4. Deploy (or let the platform auto-deploy on merge, e.g. Railway watches the repo).
# {{DEPLOY}}           e.g. railway up | (no-op: Railway auto-deploys on merge)

# 5. Healthcheck — report so the caller can verify / roll back.
# {{HEALTHCHECK}}      e.g. curl -fsS https://<app>/health

echo "✓ release.sh $VERSION complete"
