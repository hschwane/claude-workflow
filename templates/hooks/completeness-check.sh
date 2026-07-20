#!/usr/bin/env bash
# Stop hook: in unsupervised mode, keep Claude working until the task is done.
# State is the repo: an in-progress spec with unchecked subtask boxes = work remains.
#   Normal mode:       informational reminder (non-blocking).
#   Unsupervised mode: block the stop so Claude continues — unless work is complete,
#                      a blocker is recorded, or this stop was itself hook-triggered.
set -euo pipefail
INPUT=$(cat)
ROOT="${CLAUDE_PROJECT_DIR:-.}"
MEM="$ROOT/.claude/memory"
branch=$(git -C "$ROOT" branch --show-current 2>/dev/null | sed 's|/|-|g' || true)  # {branch} = git branch with / → -
CTX="$MEM/context-${branch}.md"
SHIP="$MEM/context-ship.md"   # /ship state — branch-independent

# Recorded blocker (this branch or the ship run) → human needed → allow stop.
{ [ -f "$CTX" ] && grep -q "^## Blocked" "$CTX" 2>/dev/null; } && exit 0
{ [ -f "$SHIP" ] && grep -q "^## Blocked" "$SHIP" 2>/dev/null; } && exit 0

# What's in flight: the in-progress spec (and whether it has unchecked boxes), or a ## Ship run.
SPEC=$(grep -rl "^status:[[:space:]]*in-progress" "$ROOT/docs/specs/" 2>/dev/null | head -1 || true)
HAS_SHIP=no; { [ -f "$SHIP" ] && grep -q "^## Ship" "$SHIP" 2>/dev/null; } && HAS_SHIP=yes
UNCHECKED=0
# grep -c prints 0 AND exits 1 on no match; `|| true` swallows the exit so we don't get "0\n0".
[ -n "$SPEC" ] && UNCHECKED=$(grep -c "^- \[ \]" "$SPEC" 2>/dev/null || true)

# Nothing in progress → allow stop.
[ -z "$SPEC" ] && [ "$HAS_SHIP" = no ] && exit 0

# Loop guard: don't block a stop that a Stop hook already caused.
if command -v jq >/dev/null 2>&1; then
  STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
else
  STOP_ACTIVE=$(printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && echo true || echo false)
fi

UNSUP=false
[ -f "$MEM/settings.md" ] && grep -qi '^unsupervised:[[:space:]]*true' "$MEM/settings.md" && UNSUP=true

if [ "$UNSUP" = true ] && [ "$STOP_ACTIVE" != true ]; then
  REASON="Unsupervised mode: work is still in progress ($UNCHECKED unchecked subtask(s) in ${SPEC#$ROOT/}). Continue with /implement or /ship. If genuinely blocked, write a ## Blocked section to the branch context file. If everything is done, finish the spec (move it to completed/) and clear any ## Ship note. If the usage-guard asked you to pause, stop cleanly — you will resume automatically."
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$REASON" '{decision:"block", reason:$r}'
  else
    R=$(printf '%s' "$REASON" | tr -d '"\\' | tr '\n' ' ')
    echo "{\"decision\":\"block\",\"reason\":\"$R\"}"
  fi
  exit 0
fi

# Informational only.
echo ""
echo "⚠  In-progress work: ${SPEC#$ROOT/} ($UNCHECKED unchecked subtask(s)). Resume with /resume."
exit 0
