#!/usr/bin/env bash
# Minimal rate-limit guard for unsupervised mode.
# Pauses at THRESHOLD% wherever REAL account usage is readable; does nothing where it isn't.
#
# Readable sources (in order):
#   1. .claude/memory/usage-cache.json — written by statusline.sh from the Claude Code
#      statusline stdin JSON (rate_limits.five_hour/.seven_day). Local terminal / VS Code.
#   2. OAuth usage endpoint via ~/.claude/.credentials.json (where that file exists).
# In cloud/docker neither exists (verified: no credentials file, statusline not invoked
# headless) → the guard is a no-op and the session runs into the limit; if /auto-resume is
# on the heartbeat resumes it after reset, and repo-as-checkpoint caps the loss at one subtask.
#
# Modes:  (default) PostToolUse hook — exit 2 with a pause instruction when >= threshold.
#         --status  print current usage + threshold (for /unsupervised).
set -uo pipefail
MEM="${CLAUDE_PROJECT_DIR:-.}/.claude/memory"
SETTINGS="$MEM/settings.md"; CACHE="$MEM/usage-cache.json"
CRED="${CLAUDE_CREDENTIALS:-$HOME/.claude/.credentials.json}"
MODE="${1:-hook}"

get_setting() { [ -f "$SETTINGS" ] && sed -nE "s/^$1:[[:space:]]*([^[:space:]]+).*/\1/p" "$SETTINGS" | head -1; }
UNSUP=$(get_setting unsupervised)
THRESHOLD=$(get_setting usage_threshold); case "${THRESHOLD:-}" in ''|*[!0-9]*) THRESHOLD=90;; esac

num() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*[0-9.]*" | head -1 | sed 's/.*:[[:space:]]*//'; }

# Reads real usage → prints integer max(5h%,7d%), or nothing if unreadable.
read_usage() {
  local json p5 p7
  if [ -f "$CACHE" ]; then
    # fresh cache only (<15 min); statusline keeps it current while a UI is attached
    local age; age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
    [ "$age" -lt 900 ] && json=$(cat "$CACHE" 2>/dev/null)
  fi
  if [ -z "${json:-}" ] && [ -f "$CRED" ] && command -v curl >/dev/null 2>&1; then
    local tok; tok=$(grep -o '"accessToken"[^,]*' "$CRED" 2>/dev/null | sed -E 's/.*"accessToken"[^"]*"([^"]*)".*/\1/')
    [ -n "$tok" ] && json=$(curl -sf --max-time 8 https://api.anthropic.com/api/oauth/usage \
      -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
  fi
  [ -z "${json:-}" ] && return 1
  p5=$(printf '%s' "$json" | grep -o '"five_hour"[^}]*}' | grep -oE '(used_percentage|utilization|pct)"[[:space:]]*:[[:space:]]*[0-9.]+' | grep -oE '[0-9.]+$' | head -1)
  p7=$(printf '%s' "$json" | grep -o '"seven_day"[^}]*}' | grep -oE '(used_percentage|utilization|pct)"[[:space:]]*:[[:space:]]*[0-9.]+' | grep -oE '[0-9.]+$' | head -1)
  local a=${p5%.*} b=${p7%.*}; a=${a:-0}; b=${b:-0}
  [ "$a" -ge "$b" ] 2>/dev/null && echo "$a" || echo "$b"
}

if [ "$MODE" = "--status" ]; then
  u=$(read_usage) && echo "Usage: ${u}% of the tighter window (threshold ${THRESHOLD}%)" \
                  || echo "Usage: not readable in this environment (no guard — will run into the limit; heartbeat recovers)"
  exit 0
fi

# hook mode
cat >/dev/null 2>&1 || true            # drain stdin
[ "$UNSUP" = "true" ] || exit 0        # guard only in unsupervised mode
u=$(read_usage) || exit 0              # unreadable (cloud) → no-op, run into the limit
[ "$u" -ge "$THRESHOLD" ] 2>/dev/null || exit 0
{
  echo "USAGE ${u}% ≥ ${THRESHOLD}% — pause cleanly now:"
  echo "1) finish/commit the current atomic step (green commit), 2) tick the spec box,"
  echo "3) end the turn. Do not start a new subtask. Resume when usage recovers or the user returns."
} >&2
exit 2
