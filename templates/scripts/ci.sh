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

# --- how to fill this in ---------------------------------------------------------------
# Each stage below is a `check <command>` line — a COMMAND LINE, not a comment. Replace the
# whole placeholder line, keeping the `check ` prefix. Two rules:
#
#   * Go through the package manager: `npm run lint`, `uv run ruff check .`, `cargo clippy`.
#     A bare `eslint`/`prettier`/`tsc`/`vitest` is not on PATH in GitHub Actions (they live in
#     node_modules/.bin) — it exits 127 in CI while passing on a laptop with globals installed.
#   * If a stage genuinely does not apply here, DELETE its line. Never leave the placeholder:
#     A bare placeholder token as a command aborts the run with "command not found".
#
# `check` counts what it runs, so a script with every stage deleted fails loudly at the end
# instead of reporting a pass it never earned.
# --- end of authoring notes; everything below is live code ------------------------------
CHECKS=0
check() {
  CHECKS=$((CHECKS + 1))
  echo "  → $*"
  "$@"
}

# --- prepare: generate sources the checks need ------------------------------------------
# Anything gitignored-but-required must be produced HERE, before lint/typecheck run — a fresh
# CI clone does not have it, which is how a gate passes locally and fails on the first push.
# e.g. node scripts/generate-version.js | (delete this line if nothing is generated)
{{GENERATE_SOURCES}}

# --- fast: cheap, runs on every subtask -------------------------------------------------
# e.g. check npm run format:check | check uv run ruff format --check . | check cargo fmt --check
check {{FORMAT_CHECK}}
# e.g. check npm run lint | check uv run ruff check . | check cargo clippy -- -D warnings
check {{LINT}}
# e.g. check npm run typecheck | check uv run mypy . | (compile step)
check {{TYPECHECK}}
# e.g. check npm test | check uv run pytest tests/unit | check cargo test --lib
check {{UNIT_TESTS}}

if [ "$MODE" = "full" ]; then
  # --- full: added at feature-done / merge / release -----------------------------------
  # BUILD COMES FIRST. Integration and E2E tests usually drive the built artifact — a CLI
  # binary, a container, a bundled service. Run them before the build and they exercise
  # whatever was last lying around in dist/: green on a stale artifact, or red for a
  # feature that is actually present. Neither answer is about the code you just wrote.
  # e.g. check npm run build | check docker build . | check cargo build --release
  check {{BUILD}}
  # e.g. check npm run test:integration | check uv run pytest tests/integration
  check {{INTEGRATION_TESTS}}
  # e.g. check npx playwright test | check uv run pytest tests/e2e   (delete if no E2E framework)
  check {{E2E_TESTS}}
  : # keeps this block valid if every stage above was deleted — not a check
fi

if [ "$CHECKS" -eq 0 ] && [ "${CI_ALLOW_EMPTY:-0}" != "1" ]; then
  echo "✗ ci.sh ($MODE): no checks are configured — this gate proves nothing." >&2
  echo "  Fill the stages in scripts/ci.sh. If this project genuinely has no toolchain yet," >&2
  echo "  record that in .claude/memory/tech-debt.md and set CI_ALLOW_EMPTY=1 to acknowledge it." >&2
  exit 1
fi

echo "✓ ci.sh ($MODE) passed — $CHECKS check(s)"
