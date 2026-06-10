#!/usr/bin/env bash
# Surface in-progress work at session start.
# Called on SessionStart. Stdout becomes context that Claude can see and act on.
# Note: CLAUDE.md is always loaded automatically — do NOT re-print it here (wastes tokens).
set -euo pipefail

CONTEXT_FILE=".claude/memory/context.md"

# If there's in-progress work, emit an auto-resume directive
if [ -f "$CONTEXT_FILE" ] && grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null; then
  echo "=== AUTO-RESUME REQUIRED ==="
  echo "In-progress work was interrupted. Execute /resume immediately — do not wait for user input."
  echo ""
  grep -A 20 "^## In Progress" "$CONTEXT_FILE" | head -20 || true
  echo "==========================="
fi

exit 0
