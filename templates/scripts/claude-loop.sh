#!/usr/bin/env bash
# OPTIONAL headless auto-resume for terminals / servers with no session that can
# stay open — the LOCAL counterpart of /auto-resume (cloud uses the recovery
# heartbeat instead; interactive terminals/VS Code can just leave the session open).
# Works whether or not unsupervised is on — it drives `/resume` directly.
#
# This loop restarts a headless Claude that resumes from the REPO (branch + in-progress
# spec + git log) by running `/resume` each session. It stops when there's no in-progress
# work or a ## Blocked note appears.
#
# Usage:  ./scripts/claude-loop.sh [reset_wait_minutes] [max_sessions]   (defaults: 60, 20)
# Env:    CLAUDE_LOOP_PERMISSIONS  (default: --dangerously-skip-permissions; trusted repos only)
set -euo pipefail

RESET_MINUTES=${1:-60}
MAX_SESSIONS=${2:-20}
LOG=".claude/memory/unsupervised.log"
PERMS=${CLAUDE_LOOP_PERMISSIONS:-"--dangerously-skip-permissions"}
mkdir -p .claude/memory

branch=$(git branch --show-current 2>/dev/null | sed 's|/|-|g' || true)
CTX=".claude/memory/context-${branch}.md"

in_progress() {
  # in-progress spec anywhere, or a ## Ship orchestration note
  grep -rlq "^status:[[:space:]]*in-progress" docs/specs/ 2>/dev/null && return 0
  [ -f "$CTX" ] && grep -q "^## Ship" "$CTX" 2>/dev/null && return 0
  return 1
}

for i in $(seq 1 "$MAX_SESSIONS"); do
  if [ -f "$CTX" ] && grep -q "^## Blocked" "$CTX" 2>/dev/null; then
    echo "$(date -u +%FT%TZ) blocked — stopping. See $CTX" | tee -a "$LOG"; exit 0
  fi
  if ! in_progress; then
    echo "$(date -u +%FT%TZ) no in-progress work — done." | tee -a "$LOG"; exit 0
  fi
  echo "$(date -u +%FT%TZ) session $i/$MAX_SESSIONS: resuming" | tee -a "$LOG"
  # Drive /resume directly — reconstructs state from the repo regardless of mode.
  timeout 2h claude $PERMS -p "/resume" >>"$LOG" 2>&1 || true
  # If we exited but work remains, the session likely hit the rate limit — wait for reset.
  if in_progress; then
    echo "$(date -u +%FT%TZ) work remains — waiting ${RESET_MINUTES}m for reset" | tee -a "$LOG"
    sleep $(( RESET_MINUTES * 60 ))
  fi
done
echo "$(date -u +%FT%TZ) reached max sessions ($MAX_SESSIONS)." | tee -a "$LOG"
