#!/usr/bin/env bash
# Surface in-progress work at session start — env-agnostic (local / cloud / docker / VS Code).
# State lives in the REPO: an in-progress spec + its unchecked subtask boxes + git log.
# The branch memory file is used only for ## Blocked, ## Ship (orchestration), and ## Working
# (ad-hoc work with no spec) notes.
# Stdout becomes context Claude can act on. CLAUDE.md is auto-loaded — don't reprint it.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-.}"
MEM="$ROOT/.claude/memory"
branch=$(git -C "$ROOT" branch --show-current 2>/dev/null | sed 's|/|-|g' || true)  # {branch} = git branch with / → -
CTX="$MEM/context-${branch}.md"
SHIP="$MEM/context-ship.md"   # /ship orchestration state — branch-independent (a ship spans many branches)

# Unsupervised? (drives auto-run /resume vs suggest — no marker files needed)
UNSUP=no
[ -f "$MEM/settings.md" ] && grep -qi '^unsupervised:[[:space:]]*true' "$MEM/settings.md" && UNSUP=yes
# Auto-resume? (independent of unsupervised — governs the recovery heartbeat)
AUTORES=no
[ -f "$MEM/settings.md" ] && grep -qi '^auto_resume:[[:space:]]*true' "$MEM/settings.md" && AUTORES=yes

# A blocker always takes priority — surface it, never auto-resume past it.
BLK=""
[ -f "$CTX" ] && grep -q "^## Blocked" "$CTX" 2>/dev/null && BLK="$CTX"
[ -z "$BLK" ] && [ -f "$SHIP" ] && grep -q "^## Blocked" "$SHIP" 2>/dev/null && BLK="$SHIP"
if [ -n "$BLK" ]; then
  echo "=== BLOCKED WORK ==="
  grep -A 6 "^## Blocked" "$BLK" | head -8 || true
  echo "Resolve the blocker, then /resume. ==="
  exit 0
fi

# In flight = an in-progress spec anywhere, OR an active /ship run, OR an ad-hoc ## Working note.
INPROG=$(grep -rl "^status:[[:space:]]*in-progress" "$ROOT/docs/specs/" 2>/dev/null | head -1 || true)
HAS_SHIP=no
[ -f "$SHIP" ] && grep -q "^## Ship" "$SHIP" 2>/dev/null && HAS_SHIP=yes
HAS_WORKING=no
[ -f "$CTX" ] && grep -q "^## Working" "$CTX" 2>/dev/null && HAS_WORKING=yes

if [ -z "$INPROG" ] && [ "$HAS_SHIP" = no ] && [ "$HAS_WORKING" = no ]; then
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
[ "$HAS_SHIP" = yes ] && { echo "  ship state:"; grep -A 8 "^## Ship" "$SHIP" | head -10 || true; }
[ "$HAS_WORKING" = yes ] && { echo "  ad-hoc work (## Working):"; grep -A 6 "^## Working" "$CTX" | head -8 || true; }
[ "$AUTORES" = yes ] && echo "Auto-resume is ON — ensure the recovery heartbeat is armed (see /auto-resume)."
echo "==========================="
exit 0
