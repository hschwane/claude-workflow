#!/usr/bin/env bash
# Surface in-progress work at session start.
# Called on SessionStart. Stdout becomes context that Claude can see and act on.
# Note: CLAUDE.md is always loaded automatically — do NOT re-print it here (wastes tokens).
set -euo pipefail

MEM=".claude/memory"
AUTO_MARKER="$MEM/auto-start.marker"

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

# No in-progress work anywhere → nothing to do
if [ -z "$CONTEXT_FILE" ] || ! grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null; then
  exit 0
fi

if [ -f "$AUTO_MARKER" ]; then
  # Session was started automatically by claude-loop.sh → force resume
  rm -f "$AUTO_MARKER"
  echo "=== AUTO-RESUME REQUIRED ==="
  echo "Auto-started session. Execute /resume immediately — do not wait for user input."
  echo ""
  grep -A 20 "^## In Progress" "$CONTEXT_FILE" | head -20 || true
  echo "==========================="
else
  # Manually-started session → suggest, don't force
  echo "=== IN-PROGRESS WORK FOUND ==="
  echo "There is a checkpoint from a previous session. Run /resume to continue, or start something new."
  echo ""
  grep -A 10 "^## In Progress" "$CONTEXT_FILE" | head -10 || true
  echo "=============================="
fi

exit 0
