#!/usr/bin/env bash
# Canonical check entrypoint — the SINGLE source of truth for "what the checks are".
# Claude's local gate (via the `runner` agent) AND the GitHub CI workflow both call this,
# so "passes locally" == "would pass in CI" (no drift, closes the self-grading gap).
#
# Modes:
#   ./scripts/ci.sh fast   → format-check + lint + typecheck/compile + unit tests   (per-subtask gate)
#   ./scripts/ci.sh full   → everything in fast + the build + integration/e2e       (merge / release gate)
#   ./scripts/ci.sh        → same as full
#
# project-init / project-onboard fill in the real commands for this project's language.
set -uo pipefail
# Run from the repo root whatever the caller's cwd is — CONTRIBUTING tells humans to run
# `scripts/ci.sh fast`, and a session with two source roots is often cd'd elsewhere.
cd "$(dirname "$0")/.." || exit 1
MODE="${1:-full}"

echo "▶ ci.sh ($MODE)"

# --- how to fill this in ---------------------------------------------------------------
# Each stage below is a `check <command>` line — a COMMAND LINE, not a comment. Replace the
# whole placeholder line, keeping the `check ` prefix. Three rules:
#
#   * Go through the package manager: `npm run lint`, `uv run ruff check .`, `cargo clippy`.
#     A bare `eslint`/`prettier`/`tsc`/`vitest` is not on PATH in GitHub Actions (they live in
#     node_modules/.bin) — it exits 127 in CI while passing on a laptop with globals installed.
#   * If a stage genuinely does not apply here, DELETE its line. Never leave the placeholder:
#     a bare placeholder token as a command aborts the run with "command not found".
#   * NEVER append `|| true`, `|| :` or `; true` to a stage or to the prepare line. `check` records the failure before
#     the suffix can swallow it, so the gate still fails — it just fails with a confusing
#     message instead of the real one. If a check is too noisy to keep, delete it and say so.
#
# `check` counts what it runs and remembers what failed, so a gate cannot report a pass it
# never earned: not with every stage deleted, not with a suppressed failure, and not by
# running `full` with no full-only stages configured.
# --- end of authoring notes; everything below is live code ------------------------------
CHECKS=0
FULL_CHECKS=0
FAILED=0
IN_FULL=0

# --- verdict ----------------------------------------------------------------------------
# Written where the calling session can read it directly, instead of trusting a subagent's
# prose summary of this output. Runtime state: gitignored.
write_result() {
  local status="$1"
  mkdir -p .claude/memory 2>/dev/null || true
  # `dirty` covers uncommitted work: HEAD does not move when a file is edited, so a
  # sha-only record lets a caller skip the gate on a tree that changed since it ran.
  local dirty=false
  [ -n "$(git status --porcelain 2>/dev/null)" ] && dirty=true
  printf '{"mode":"%s","status":"%s","checks":%d,"full_checks":%d,"failed":%d,"sha":"%s","dirty":%s}\n' \
    "$MODE" "$status" "$CHECKS" "$FULL_CHECKS" "$FAILED" \
    "$(git rev-parse --verify -q HEAD || echo unknown)" "$dirty" \
    > .claude/memory/last-gate.json 2>/dev/null || true
}


prepare() {
  echo "  ⚙ $*"
  "$@"
  local code=$?
  [ "$code" -eq 0 ] && return 0
  echo "  ✗ PREPARE FAILED (exit $code): $*" >&2
  echo "✗ ci.sh ($MODE): a preparation step failed; the checks would run against missing or stale sources." >&2
  FAILED=1
  write_result failed
  exit "$code"
}

check() {
  CHECKS=$((CHECKS + 1))
  [ "$IN_FULL" -eq 1 ] && FULL_CHECKS=$((FULL_CHECKS + 1))
  echo "  → $*"
  # Capture the status of the command itself. Do NOT wrap this in `if "$@"; then …; fi`
  # and read $? afterwards: $? is then the status of the completed `if`, which is 0, so a
  # failing check would report "FAILED (exit 0)" and exit 0 — a green gate on a red check.
  "$@"
  local code=$?
  [ "$code" -eq 0 ] && return 0
  FAILED=1
  echo "  ✗ FAILED (exit $code): $*" >&2
  echo "✗ ci.sh ($MODE): failed at check $CHECKS of $CHECKS run." >&2
  write_result failed
  # `exit`, not `return` — a `|| true` appended to the stage would swallow a return code
  # and let the gate report green on a failed check. Exiting here means the suffix is
  # never evaluated, so the suppression trick cannot work at all.
  exit "$code"
}

# --- prepare: generate sources the checks need ------------------------------------------
# Anything gitignored-but-required must be produced HERE, before lint/typecheck run — a fresh
# CI clone does not have it, which is how a gate passes locally and fails on the first push.
# Keep the `prepare ` prefix: this script does not use `set -e`, so an unwrapped command that
# fails is simply ignored and the gate goes on to report a pass with the file still missing.
# e.g. prepare node scripts/generate-version.js | (delete this line if nothing is generated)
prepare {{GENERATE_SOURCES}}

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
  IN_FULL=1
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
  write_result empty
  exit 1
fi

if [ "$MODE" = "full" ] && [ "$FULL_CHECKS" -eq 0 ] && [ "${FULL_ALLOW_NONE:-0}" != "1" ]; then
  echo "✗ ci.sh (full): no full-only stages are configured — 'full' ran exactly what 'fast' runs." >&2
  echo "  A merge or release gated on this proves nothing more than a per-subtask check did." >&2
  echo "  Add the build and integration stages, or set FULL_ALLOW_NONE=1 if this project" >&2
  echo "  genuinely has neither and record that in .claude/memory/tech-debt.md." >&2
  write_result full-degraded
  exit 1
fi

write_result passed
echo "✓ ci.sh ($MODE) passed — $CHECKS check(s)$([ "$MODE" = full ] && echo ", $FULL_CHECKS full-only")"
