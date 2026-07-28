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

# Each placeholder below is a COMMAND LINE, not a comment. Replace the whole line with the
# real command; delete the line for a step this project does not have. A step left as a
# comment makes this script report a successful release having published nothing.

# 2. Build the release artifact.
# ci.sh full above already ran this project's build stage, so this line is for an
# artifact the gate does not produce (a container image, a signed tarball). If the
# gate's build IS the artifact, delete this line rather than building twice.
# e.g. docker build -t app:$VERSION . | tar czf dist/app-$VERSION.tgz -C dist .
{{BUILD_ARTIFACT}}

# 3. Publish (only where creds are present locally; otherwise this is the CI fallback's job).
# e.g. npm publish | twine upload dist/* | docker push app:$VERSION | gh release create v$VERSION --generate-notes
{{PUBLISH}}

# 4. Deploy (or let the platform auto-deploy on merge, e.g. Railway watches the repo).
# e.g. railway up | : (no-op — Railway auto-deploys on merge)
{{DEPLOY}}

# 5. Healthcheck — report so the caller can verify / roll back.
# e.g. curl -fsS https://<app>/health
{{HEALTHCHECK}}

echo "✓ release.sh $VERSION complete"
