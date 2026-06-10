#!/usr/bin/env bash
# Stop hook: handle unfinished work when Claude tries to stop.
#
# Normal mode:       print an informational reminder for the user (non-blocking).
# Unsupervised mode: block the stop (JSON decision) so Claude keeps working,
#                    unless work is complete, a blocker is recorded, or this
#                    stop was already triggered by a Stop hook (loop guard).
set -euo pipefail

INPUT=$(cat)

CONTEXT_FILE=".claude/memory/context.md"
SETTINGS_FILE=".claude/memory/settings.md"

[ ! -f "$CONTEXT_FILE" ] && exit 0

# No in-progress work → nothing to do
grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null || exit 0

# A recorded blocker means human attention is required → allow stopping
if grep -q "^## Blocked" "$CONTEXT_FILE" 2>/dev/null; then
  exit 0
fi

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
  # Block the stop and tell Claude to continue the checkpointed work
  echo '{"decision": "block", "reason": "Unsupervised mode is active and .claude/memory/context.md still contains an In Progress section. Continue the work from the checkpoint (next_step). If you are genuinely blocked, write a Blocked section to .claude/memory/context.md; if the work is complete, clear the In Progress section."}'
  exit 0
fi

# Informational reminder only (shown in transcript, does not block)
echo ""
echo "⚠  There is in-progress work recorded in .claude/memory/context.md"
echo ""
grep -A 10 "^## In Progress" "$CONTEXT_FILE" || true
echo ""
echo "Resume later with /resume, or run unattended: ./scripts/claude-loop.sh"

exit 0
