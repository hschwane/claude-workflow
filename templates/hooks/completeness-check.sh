#!/usr/bin/env bash
# Remind Claude of unfinished work when a session ends.
# Called by Stop hook. Outputs a reminder if work is in progress.
set -euo pipefail

CONTEXT_FILE=".claude/memory/context.md"

[ ! -f "$CONTEXT_FILE" ] && exit 0

# Check if there's active in-progress work
if grep -q "^## In Progress" "$CONTEXT_FILE" 2>/dev/null; then
  echo ""
  echo "⚠  There is in-progress work recorded in .claude/memory/context.md"
  echo ""
  grep -A 10 "^## In Progress" "$CONTEXT_FILE" || true
  echo ""
  echo "To resume automatically after rate limit resets, run in a terminal:"
  echo "  ./scripts/claude-loop.sh [minutes until reset]"
  echo ""
  echo "Or start a new session — Claude will resume automatically."
fi

exit 0
