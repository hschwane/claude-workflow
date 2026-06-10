#!/usr/bin/env bash
# Unsupervised mode supervisor.
# Runs Claude in a loop, automatically resuming after rate limit resets.
# Claude will not ask interactive questions; any genuine blocker is written
# to .claude/memory/context.md as "## Blocked" and this script exits.
#
# Usage:
#   ./scripts/claude-loop.sh                  # default: 60min reset, 20 sessions max
#   ./scripts/claude-loop.sh 60               # reset wait in minutes
#   ./scripts/claude-loop.sh 60 20            # reset minutes + max session count
#
# Prerequisites:
#   - In-progress work in .claude/memory/context.md (set up via /unsupervised on, then start task)
#   - claude CLI available in PATH

set -euo pipefail

RESET_MINUTES=${1:-60}
MAX_SESSIONS=${2:-20}
SESSION_TIMEOUT="2h"   # kill a session that hangs waiting for input
CONTEXT_FILE=".claude/memory/context.md"
LOG_FILE=".claude/memory/unsupervised.log"

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
log "Log: $LOG_FILE"
echo ""

# ── Main loop ─────────────────────────────────────────────────────────────────

SESSION=0
while [ $SESSION -lt $MAX_SESSIONS ]; do
  SESSION=$((SESSION + 1))
  log "Session $SESSION / $MAX_SESSIONS starting..."

  # Run Claude with a timeout so it can't hang forever waiting for user input.
  # SessionStart hook fires → AUTO-RESUME REQUIRED → Claude continues the task.
  EXIT=0
  timeout "$SESSION_TIMEOUT" claude --continue || EXIT=$?

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

  # Still in progress — session ended due to rate limit or timeout
  if [ $EXIT -eq 124 ]; then
    log "Session timed out (>${SESSION_TIMEOUT}). Restarting immediately."
  else
    log "Session ended (exit $EXIT). Waiting ${RESET_MINUTES}min for rate limit reset..."
    SECS=$((RESET_MINUTES * 60))
    while [ $SECS -gt 0 ]; do
      sleep 60
      SECS=$((SECS - 60))
      [ $SECS -gt 0 ] && log "  ${SECS}s remaining..."
    done
    log "Reset wait complete."
  fi
done

log "Max sessions ($MAX_SESSIONS) reached without completing the task."
echo ""
echo "Max retries reached. Check $CONTEXT_FILE for current status."
exit 1
