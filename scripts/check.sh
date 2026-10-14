#!/usr/bin/env bash
# The plugin's own gate.
#
#   ./scripts/check.sh               fast checks (seconds)
#   ./scripts/check.sh --languages   also execute the per-language stage commands (~4 min)
#
# Mechanical checks only: what a human review reliably misses and a script never does.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAILED=0
fail() { echo "  ✗ $*" >&2; FAILED=$((FAILED + 1)); }
ok()   { echo "  ✓ $*"; }

echo "▶ wf self-check"

echo "shell syntax + modes"
BEFORE=$FAILED
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || fail "bash -n: $f"
  [ -x "$f" ] || fail "not executable: $f"
done < <(git ls-files '*.sh')
[ "$FAILED" -eq "$BEFORE" ] && ok "$(git ls-files '*.sh' | wc -l | tr -d ' ') scripts parse and are executable"

echo "plugin manifest + components"
if command -v claude >/dev/null; then
  out=$(claude plugin validate . 2>&1); code=$?
  if [ "$code" -ne 0 ] || echo "$out" | grep -q "✘\|Found [0-9]* error"; then
    echo "$out" | sed 's/^/    /' >&2; fail "claude plugin validate"
  else
    ok "claude plugin validate passes"
  fi
else
  echo "  ⚠ not run — the claude CLI is not on PATH"
fi

echo "skill + agent frontmatter"
BEFORE=$FAILED
for f in skills/*/SKILL.md; do
  head -12 "$f" | grep -q '^name:'        || fail "no name: in $f"
  head -12 "$f" | grep -q '^description:' || fail "no description: in $f"
  n=$(awk -F': ' '/^name:/{print $2; exit}' "$f")
  [ "$n" = "$(basename "$(dirname "$f")")" ] || fail "name '$n' != directory in $f"
done
for f in agents/*.md; do
  head -12 "$f" | grep -q '^name:'        || fail "no name: in $f"
  head -12 "$f" | grep -q '^description:' || fail "no description: in $f"
done
[ "$FAILED" -eq "$BEFORE" ] && ok "$(ls -d skills/*/ | wc -l | tr -d ' ') skills and $(ls agents/*.md | wc -l | tr -d ' ') agent(s) carry name + description"

# Small enough to maintain: the procedure prose a session loads. Guideline references are
# reference material read on demand and are not counted.
echo "prose budget"
words=$(cat skills/*/SKILL.md skills/setup/decisions.md agents/*.md | wc -w | tr -d ' ')
if [ "$words" -le 9000 ]; then ok "$words words of skill + agent prose (budget 9000)"; else fail "$words words of skill + agent prose — over the 9000 budget"; fi

echo "no v3 machinery left"
BEFORE=$FAILED
for p in "\.claude/memory" "workflow-settings" "/workflow-update" "delivery\.json" "project-scaffolder" "smoke-tester" "gate-status" "criteria-check" "/implement" "/plan " "\.claude/guidelines"; do
  hits=$(git ls-files skills agents templates hooks 2>/dev/null | grep -v '^skills/convert/' | xargs grep -l -- "$p" 2>/dev/null || true)
  [ -z "$hits" ] || fail "'$p' still referenced in: $hits"
done
[ "$FAILED" -eq "$BEFORE" ] && ok "only /wf:convert mentions the old plugin's files"

echo "ci.sh / release.sh / healthcheck.sh integrity"
python3 scripts/_check_gate.py || FAILED=$((FAILED + 1))

echo "cross-file consistency"
python3 scripts/_check_consistency.py || FAILED=$((FAILED + 1))

echo "mod tests"
if [ -f hooks/hooks.json ] && command -v claude >/dev/null; then
  if out=$(claude plugin test . 2>&1); then ok "claude plugin test passes"; else echo "$out" | tail -20 | sed 's/^/    /' >&2; fail "claude plugin test"; fi
else
  echo "  ⚠ not run — no mod or no claude CLI"
fi

echo "language stage commands"
if [ "${1:-}" = "--languages" ]; then
  python3 scripts/_check_languages.py || FAILED=$((FAILED + 1))
else
  echo "  ⚠ not run — ./scripts/check.sh --languages executes them (installs toolchains, ~4 min)"
fi

echo
if [ "$FAILED" -gt 0 ]; then echo "✗ self-check: $FAILED problem(s)" >&2; exit 1; fi
echo "✓ self-check passed"
