#!/usr/bin/env bash
# UserPromptSubmit hook: covers auto-resume for ORDINARY prompts too, not just /implement,
# /ship, /resume, /unsupervised. Those skills arm the heartbeat explicitly at known points;
# this hook is the ambient fallback so a plain "do X" prompt that happens to run long (or one
# sent right before the limit resets) is still recoverable — without the user having to route
# everything through a named skill.
#
# No-op (near-zero cost: one file read + one env check) unless auto_resume:true AND this is a
# cloud/remote session. Its stdout becomes context Claude sees alongside the prompt — it can't
# call MCP tools itself, so it reminds Claude to (a) ensure the heartbeat is armed and (b) keep
# a lightweight '## Working' checkpoint for ad-hoc (non-spec) work, since /resume's repo-based
# reconstruction has nothing else to go on for work that isn't a spec or a /ship run.
set -uo pipefail
cat >/dev/null 2>&1 || true   # drain stdin (the prompt JSON) — content not needed

ROOT="${CLAUDE_PROJECT_DIR:-.}"
MEM="$ROOT/.claude/memory"
SETTINGS="$MEM/settings.md"

[ -f "$SETTINGS" ] || exit 0
grep -qi '^auto_resume:[[:space:]]*true' "$SETTINGS" 2>/dev/null || exit 0

# Cloud/remote only — the heartbeat mechanism doesn't exist locally (claude-loop.sh covers
# local auto-resume instead, and doesn't need arming).
[ -n "${CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE:-}" ] || exit 0

branch=$(git -C "$ROOT" branch --show-current 2>/dev/null | sed 's|/|-|g' || true)
echo "[auto-resume] auto_resume is ON in this cloud session. Before starting any non-trivial or multi-step work this turn: ensure the recovery heartbeat is armed (idempotent — see /auto-resume). If this task isn't already tracked by an in-progress spec or a /ship run, write/update a short '## Working' note in .claude/memory/context-${branch}.md describing what you're doing, so a limit kill mid-task can still be recovered from the repo state. Clear the note once the task is fully done this turn — skip all of this for a quick/trivial reply."
exit 0
