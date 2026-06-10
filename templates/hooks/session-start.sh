#!/usr/bin/env bash
# Re-inject root CLAUDE.md summary after session compaction.
# Called on SessionStart. Outputs text that Claude sees as context.
set -euo pipefail

CLAUDE_MD="CLAUDE.md"
CONTEXT_FILE=".claude/memory/context.md"

# Print the first 60 lines of CLAUDE.md as a reminder
if [ -f "$CLAUDE_MD" ]; then
  echo "=== Project Context (from CLAUDE.md) ==="
  head -60 "$CLAUDE_MD"
  echo "========================================"
fi

# If there's in-progress work, emit an auto-resume directive
if [ -f "$CONTEXT_FILE" ] && grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null; then
  echo ""
  echo "=== AUTO-RESUME REQUIRED ==="
  echo "In-progress work was interrupted. Execute /resume immediately — do not wait for user input."
  echo ""
  grep -A 20 "^## In Progress" "$CONTEXT_FILE" | head -20 || true
  echo "==========================="
  echo ""
fi

exit 0
