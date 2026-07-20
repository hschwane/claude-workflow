#!/usr/bin/env bash
# Canonical check entrypoint — the SINGLE source of truth for "what the checks are".
# Claude's local gate (via the `runner` agent) AND the GitHub CI workflow both call this,
# so "passes locally" == "would pass in CI" (no drift, closes the self-grading gap).
#
# Modes:
#   ./scripts/ci.sh fast   → format-check + lint + typecheck/compile + unit tests   (per-subtask gate)
#   ./scripts/ci.sh full   → everything in fast + integration/e2e + the deployable build
#   ./scripts/ci.sh        → same as full
#
# project-init / project-onboard fill in the real commands for this project's language.
# Keep every command FAST-FAILing (set -e) so the first failure is the report.
set -euo pipefail
MODE="${1:-full}"

echo "▶ ci.sh ($MODE)"

# --- fast: cheap, runs on every subtask ------------------------------------------------
# {{FORMAT_CHECK}}   e.g. prettier --check . | ruff format --check . | cargo fmt --check
# {{LINT}}           e.g. eslint . | ruff check . | cargo clippy -- -D warnings
# {{TYPECHECK}}      e.g. tsc --noEmit | mypy . | (compile step)
# {{UNIT_TESTS}}     e.g. vitest run unit | pytest tests/unit | cargo test --lib

if [ "$MODE" = "full" ]; then
  # --- full: added at feature-done / merge / release -----------------------------------
  # {{INTEGRATION_TESTS}}  e.g. vitest run integration | pytest tests/integration
  # {{E2E_TESTS}}          e.g. playwright test | pytest tests/e2e
  # {{BUILD}}              e.g. npm run build | docker build . | cargo build --release
  :
fi

echo "✓ ci.sh ($MODE) passed"
