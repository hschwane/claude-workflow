#!/usr/bin/env bash
# Canonical dev-environment entrypoint — brings up the environment Claude tests in.
#
#   ./scripts/dev.sh          → prepare (deps, migrations, test data) and start, in the foreground
#   ./scripts/dev.sh --info   → print how to reach it (URL, test credentials) and exit
#
# `--info` exists so the caller can hand its output to the smoke-tester verbatim as HOW_TO_RUN.
# Before this script, every /verify re-derived "how do I start this thing with test data" from
# scratch; the agent is blackbox and cannot work it out, so the cost landed on the main session
# once per ticket, forever.
#
# TEST DATA ONLY — never a database or an account you care about, and never production. The
# environment is started on demand and stopped right after use; it tracks no branch and needs
# no deploy automation.
#
# Real APIs are preferred wherever they can be used; mock only what genuinely cannot. Anything
# that costs money or tokens needs the user's permission first — see .claude/guidelines/app-baseline.md.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# Fails open: with `dirname` off PATH the expansion is empty and `cd "/.."` succeeds.
[ -f scripts/dev.sh ] || { echo "✗ dev.sh: not in the repo root (cwd=$PWD)." >&2; exit 1; }

# --- how to fill this in ---------------------------------------------------------------
# DEV_INFO is what the smoke-tester is told; it must be enough to drive the app without any
# other knowledge — the exact URL or command, and any test credentials. "Runs on localhost"
# is not enough. Each `step` line is a COMMAND LINE, not a comment; delete the ones this
# project does not need, and never append `|| true`.
# --- end of authoring notes; everything below is live code ------------------------------
DEV_INFO="{{DEV_INFO}}"

if [ "${1:-}" = "--info" ]; then
  printf '%s\n' "$DEV_INFO"
  exit 0
fi

STEPS=0
step() {
  STEPS=$((STEPS + 1))
  echo "  → $*"
  "$@"
  local code=$?
  [ "$code" -eq 0 ] && return 0
  echo "  ✗ FAILED (exit $code): $*" >&2
  echo "✗ dev.sh: setup failed; the environment is not ready to test against." >&2
  exit "$code"
}

echo "▶ dev.sh"
# e.g. step npm ci | step uv sync
{{DEV_INSTALL}}
# e.g. step npm run migrate:up   (against the TEST database — delete if no database)
{{DEV_MIGRATE}}
# e.g. step npm run seed:test    (delete if the app needs no fixtures)
{{DEV_SEED}}

if [ "$STEPS" -eq 0 ] && [ "${DEV_ALLOW_EMPTY:-0}" != "1" ]; then
  echo "✗ dev.sh: no setup steps are configured, so 'the environment is ready' is unproven." >&2
  echo "  Fill the steps in scripts/dev.sh. If this project genuinely needs no setup at all," >&2
  echo "  set DEV_ALLOW_EMPTY=1 to say so deliberately." >&2
  exit 1
fi

echo "── ready ──"
printf '%s\n' "$DEV_INFO"
# The last line RUNS the app and does not return; the caller backgrounds this script and stops
# it when the test is done. e.g. exec npm run dev | exec uv run uvicorn app:app --reload
{{DEV_RUN}}
