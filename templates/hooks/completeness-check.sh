#!/usr/bin/env bash
# Stop hook: handle unfinished work when Claude tries to stop.
#
# Normal mode:       print an informational reminder for the user (non-blocking).
# Unsupervised mode: block the stop (JSON decision) so Claude keeps working,
#                    unless work is complete, a blocker is recorded, or this
#                    stop was already triggered by a Stop hook (loop guard).
set -euo pipefail

INPUT=$(cat)

MEM=".claude/memory"
SETTINGS_FILE="$MEM/settings.md"

# Determine branch-scoped context file, with fallback to legacy context.md
branch_context() {
  local branch
  branch=$(git branch --show-current 2>/dev/null | sed 's|/|-|g')
  if [ -n "$branch" ] && [ -f "$MEM/context-${branch}.md" ]; then
    echo "$MEM/context-${branch}.md"
  elif [ -f "$MEM/context.md" ]; then
    echo "$MEM/context.md"
  else
    echo ""
  fi
}

CONTEXT_FILE=$(branch_context)

[ -z "$CONTEXT_FILE" ] && exit 0

# No in-progress work → nothing to do
grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null || exit 0

# A recorded blocker means human attention is required → allow stopping
if grep -q "^## Blocked" "$CONTEXT_FILE" 2>/dev/null; then
  exit 0
fi

# Usage threshold reached while running under claude-loop.sh → allow stop.
# The loop will restart a fresh session (empty context window) and resume from checkpoint.
# Both markers must be present: loop-mode (set by claude-loop.sh) + usage-wait (set by usage-guard hook).
if [ -f "$MEM/loop-mode.marker" ] && [ -f "$MEM/usage-wait.active" ]; then
  exit 0
fi

# Collect remaining unchecked tasks (for display and block reason)
UNCHECKED=$(grep "^- \[ \]" "$CONTEXT_FILE" 2>/dev/null || true)
UNCHECKED_COUNT=$(echo "$UNCHECKED" | grep -c "." || true)   # grep -c already prints 0 on no match

# Loop guard: if this stop was already caused by a Stop hook, don't block again
if command -v jq &>/dev/null; then
  STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
else
  STOP_ACTIVE=$(echo "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && echo "true" || echo "false")
fi

UNSUPERVISED=false
if [ -f "$SETTINGS_FILE" ] && grep -q "^unsupervised: true" "$SETTINGS_FILE" 2>/dev/null; then
  UNSUPERVISED=true
fi

if [ "$UNSUPERVISED" = "true" ] && [ "$STOP_ACTIVE" != "true" ]; then
  # Build a block reason that lists remaining tasks when present
  if [ "$UNCHECKED_COUNT" -gt 0 ] 2>/dev/null; then
    REMAINING_MSG="Remaining tasks ($UNCHECKED_COUNT): $(echo "$UNCHECKED" | head -5 | tr '\n' ' ')"
  else
    REMAINING_MSG="Check the checkpoint for next_step."
  fi
  REASON="Unsupervised mode is active and the branch context file still contains an In Progress section. $REMAINING_MSG Continue working through the task list in order. If the usage threshold was reached: check whether .claude/memory/loop-mode.marker exists — if yes, stop cleanly (claude-loop.sh will restart); if no, run bash .claude/hooks/usage-guard.sh --wait repeatedly until RESUME_OK, then continue. If you are genuinely blocked, write a Blocked section to the context file; if all work is complete, clear the In Progress section."
  if command -v jq &>/dev/null; then
    # jq handles JSON escaping (task text may contain quotes/backslashes)
    jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  else
    # No jq: strip characters that would break the hand-built JSON string
    REASON=$(printf '%s' "$REASON" | tr -d '"\\' | tr '\n' ' ')
    echo "{\"decision\": \"block\", \"reason\": \"$REASON\"}"
  fi
  exit 0
fi

# Informational reminder only (shown in transcript, does not block)
echo ""
echo "⚠  There is in-progress work recorded in $CONTEXT_FILE"
if [ "$UNCHECKED_COUNT" -gt 0 ] 2>/dev/null; then
  echo "   $UNCHECKED_COUNT task(s) still unchecked:"
  echo "$UNCHECKED" | head -5 | sed 's/^/   /'
fi
echo ""
grep -A 10 "^## In Progress" "$CONTEXT_FILE" || true
echo ""
echo "Resume later with /resume, or run unattended: ./scripts/claude-loop.sh"

exit 0
