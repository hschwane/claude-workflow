#!/usr/bin/env bash
# Surface in-progress work at session start — env-agnostic (local / cloud / docker / VS Code).
# State lives in the REPO: an in-progress spec + its unchecked subtask boxes + git log.
# The branch memory file is used only for ## Blocked and ## Ship (orchestration) notes.
# Stdout becomes context Claude can act on. CLAUDE.md is auto-loaded — don't reprint it.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-.}"
MEM="$ROOT/.claude/memory"
branch=$(git -C "$ROOT" branch --show-current 2>/dev/null | sed 's|/|-|g' || true)
CTX="$MEM/context-${branch}.md"

# Unsupervised? (drives auto-resume vs suggest — no marker files needed)
UNSUP=no
[ -f "$MEM/settings.md" ] && grep -qi '^unsupervised:[[:space:]]*true' "$MEM/settings.md" && UNSUP=yes

# A blocker always takes priority — surface it, never auto-resume past it.
if [ -f "$CTX" ] && grep -q "^## Blocked" "$CTX" 2>/dev/null; then
  echo "=== BLOCKED WORK ON THIS BRANCH ==="
  grep -A 6 "^## Blocked" "$CTX" | head -8 || true
  echo "Resolve the blocker, then /resume. ==="
  exit 0
fi

# In-progress spec on this branch = a spec still marked in-progress with unchecked boxes.
INPROG=$(grep -rl "^status:[[:space:]]*in-progress" "$ROOT/docs/specs/" 2>/dev/null | head -1 || true)
HAS_SHIP=no
[ -f "$CTX" ] && grep -q "^## Ship" "$CTX" 2>/dev/null && HAS_SHIP=yes

if [ -z "$INPROG" ] && [ "$HAS_SHIP" = no ]; then
  exit 0   # nothing in flight
fi

if [ "$UNSUP" = yes ]; then
  echo "=== AUTO-RESUME REQUIRED ==="
  echo "Unsupervised mode + in-progress work found. Execute /resume immediately — do not wait for input."
else
  echo "=== IN-PROGRESS WORK FOUND ==="
  echo "Run /resume to continue, or start something new."
fi
[ -n "$INPROG" ] && echo "  spec: ${INPROG#$ROOT/}"
[ "$HAS_SHIP" = yes ] && { echo "  ship state:"; grep -A 8 "^## Ship" "$CTX" | head -10 || true; }
echo "==========================="
exit 0
