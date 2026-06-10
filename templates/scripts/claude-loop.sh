#!/usr/bin/env bash
# Unsupervised mode supervisor.
# Runs Claude headless in a loop, automatically resuming after rate limit resets.
# Claude will not ask interactive questions; any genuine blocker is written
# to .claude/memory/context.md as "## Blocked" and this script exits.
#
# Usage:
#   ./scripts/claude-loop.sh                  # default: 60min reset wait, 20 sessions max
#   ./scripts/claude-loop.sh 60               # reset wait in minutes
#   ./scripts/claude-loop.sh 60 20            # reset minutes + max session count
#
# Environment:
#   CLAUDE_LOOP_PERMISSIONS  Extra permission flags passed to claude.
#                            Default: "--dangerously-skip-permissions"
#                            (required for unattended runs — tool calls would
#                            otherwise hang on permission prompts. Only use in
#                            a trusted repository, ideally in a container/VM.)
#
# Prerequisites:
#   - In-progress work in .claude/memory/context.md (set up via /unsupervised on, then start task)
#   - claude CLI available in PATH

set -euo pipefail

RESET_MINUTES=${1:-60}
MAX_SESSIONS=${2:-20}
SESSION_TIMEOUT="2h"   # kill a session that hangs
CONTEXT_FILE=".claude/memory/context.md"
LOG_FILE=".claude/memory/unsupervised.log"
PERMISSION_FLAGS=${CLAUDE_LOOP_PERMISSIONS:-"--dangerously-skip-permissions"}
RESUME_PROMPT="Unsupervised mode: continue the in-progress work recorded in .claude/memory/context.md. Follow the /resume skill: read the checkpoint, verify the git state, and continue from next_step. Do not ask questions; apply autonomous defaults. If blocked, write a '## Blocked' section to .claude/memory/context.md and stop. When everything is complete, clear the '## In Progress' section."

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

has_in_progress() {
  grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null
}

has_blocked() {
  grep -q "^## Blocked" "$CONTEXT_FILE" 2>/dev/null
}

# ── Preflight ──────────────────────────────────────────────────────────────────

if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found in PATH." >&2
  exit 1
fi

if [ ! -f "$CONTEXT_FILE" ]; then
  echo "Error: $CONTEXT_FILE not found. Run /unsupervised on and start a task first." >&2
  exit 1
fi

if ! has_in_progress; then
  echo "No in-progress work found in $CONTEXT_FILE. Nothing to do." >&2
  exit 0
fi

mkdir -p ".claude/memory"
log "Unsupervised loop started. Reset: ${RESET_MINUTES}min, max sessions: ${MAX_SESSIONS}."
log "Permissions: $PERMISSION_FLAGS"
log "Log: $LOG_FILE"
echo ""

# ── Main loop ─────────────────────────────────────────────────────────────────

SESSION=0
while [ $SESSION -lt $MAX_SESSIONS ]; do
  SESSION=$((SESSION + 1))
  log "Session $SESSION / $MAX_SESSIONS starting..."

  # Headless run (-p): claude executes one autonomous session and exits.
  # Each session starts FRESH on purpose — all needed state lives in the
  # checkpoint (.claude/memory/context.md), which the SessionStart hook
  # injects. Fresh sessions are deterministic, work on the first run, and
  # don't re-load a huge prior conversation right after a rate limit.
  EXIT=0
  timeout "$SESSION_TIMEOUT" claude -p "$RESUME_PROMPT" \
    $PERMISSION_FLAGS 2>&1 | tee -a "$LOG_FILE" || EXIT=$?

  # ── Evaluate outcome ────────────────────────────────────────────────────────

  if has_blocked; then
    log "BLOCKED — human input required. Stopping loop."
    echo ""
    echo "══════════════════════════════════════"
    echo "  BLOCKED — action required:"
    grep -A 10 "^## Blocked" "$CONTEXT_FILE" || true
    echo "══════════════════════════════════════"
    exit 2
  fi

  if ! has_in_progress; then
    log "All tasks complete. Unsupervised loop finished."
    echo ""
    echo "══════════════════════════════════════"
    echo "  DONE — no in-progress work remains."
    echo "══════════════════════════════════════"
    exit 0
  fi

  # Still in progress — session ended due to rate limit, error, or timeout
  if [ $EXIT -eq 124 ]; then
    log "Session timed out (>${SESSION_TIMEOUT}). Restarting immediately."
  else
    log "Session ended (exit $EXIT). Waiting ${RESET_MINUTES}min for rate limit reset..."
    sleep $((RESET_MINUTES * 60))
    log "Reset wait complete."
  fi
done

log "Max sessions ($MAX_SESSIONS) reached without completing the task."
echo ""
echo "Max retries reached. Check $CONTEXT_FILE for current status."
exit 1
