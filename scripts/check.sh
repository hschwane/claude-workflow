#!/usr/bin/env bash
# The plugin's own gate. This repo sells "never ship on an unrun gate" and had none —
# six manual defect hunts were the entire quality story, so any SKILL.md edit could
# silently reintroduce a fixed defect class.
#
#   ./scripts/check.sh
#
# Mechanical checks only: the things a human review reliably misses and a script never does.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAILED=0
BEFORE=0
fail() { echo "  ✗ $*" >&2; FAILED=$((FAILED + 1)); }
ok()   { echo "  ✓ $*"; }

echo "▶ claude-workflow self-check"

# --- 1. every shell script parses, and is executable -------------------------------------
BEFORE=$FAILED
echo "shell syntax + modes"
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || fail "bash -n: $f"
  [ -x "$f" ] || fail "not executable: $f"
done < <(git ls-files '*.sh')
# Run shellcheck where available, on the files that are real shell (templates hold {{TOKENS}}).
# NB: a comment whose first word is "shellcheck" is parsed as a directive and errors out.
if command -v shellcheck >/dev/null; then
  git ls-files '*.sh' | grep -v '^templates/scripts/' \
    | xargs shellcheck -S warning >/dev/null 2>&1 || fail "shellcheck found problems (run it for detail)"
fi
[ "$FAILED" -eq "$BEFORE" ] && ok "$(git ls-files '*.sh' | wc -l | tr -d ' ') scripts parse and are executable"

# --- 2. delivery.json is valid, and every `source` it names exists ------------------------
echo "delivery manifest"
python3 - <<'PY' || FAILED=$((FAILED + 1))
import json, os, sys
try:
    d = json.load(open(".claude-plugin/delivery.json"))
except Exception as e:
    print(f"  ✗ delivery.json does not parse: {e}", file=sys.stderr); sys.exit(1)
bad = [e["path"] for e in d["entries"] if e.get("source") and not os.path.exists(e["source"])]
dupes = {p for p in (e["path"] for e in d["entries"]) if list(e["path"] for e in d["entries"]).count(p) > 1}
for p in bad:   print(f"  ✗ manifest source missing for: {p}", file=sys.stderr)
for p in dupes: print(f"  ✗ duplicate manifest path: {p}", file=sys.stderr)
if bad or dupes: sys.exit(1)
print(f"  ✓ {len(d['entries'])} entries, every source resolves, no duplicate paths")
PY

# --- 3. skills and agents have the frontmatter the harness needs --------------------------
echo "skill + agent frontmatter"
for f in skills/*/SKILL.md; do
  head -12 "$f" | grep -q '^name:'        || fail "no name: in $f"
  head -12 "$f" | grep -q '^description:' || fail "no description: in $f"
  n=$(awk -F': ' '/^name:/{print $2; exit}' "$f")
  d=$(basename "$(dirname "$f")")
  [ "$n" = "$d" ] || fail "name '$n' != directory '$d' in $f"
done
for f in agents/*.md; do
  head -12 "$f" | grep -q '^name:'        || fail "no name: in $f"
  head -12 "$f" | grep -q '^description:' || fail "no description: in $f"
done

# --- 4. the gate template cannot report a pass it did not earn ---------------------------
# The defect class this repo exists to prevent, asserted rather than trusted.
BEFORE=$FAILED
echo "ci.sh integrity"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 - "$T" <<'PY'
import re, sys
t = sys.argv[1]
s = open("templates/scripts/ci.sh").read()
def fill(full=True, soften=False, empty=False, failing=False):
    x = s.replace("{{GENERATE_SOURCES}}", "true")
    for k, v in [("FORMAT_CHECK","true"),("LINT","true"),("TYPECHECK","true"),("UNIT_TESTS","true")]:
        x = x.replace("check {{%s}}" % k, "check %s" % v)
    if full:
        for k in ("BUILD","INTEGRATION_TESTS","E2E_TESTS"):
            x = x.replace("check {{%s}}" % k, "check true")
    else:
        x = re.sub(r"^\s*check \{\{(BUILD|INTEGRATION_TESTS|E2E_TESTS)\}\}\s*\n", "", x, flags=re.M)
    if soften:  x = x.replace("check true", 'check sh -c "exit 3" || true', 1)
    if failing: x = x.replace("check true", 'check sh -c "exit 3"', 1)
    if empty:   x = re.sub(r"^\s*check \S.*\n", "", x, flags=re.M)
    return x
for name, kw in [("pass",{}),("degraded",{"full":False}),("soft",{"soften":True}),
                 ("fail",{"failing":True}),("empty",{"full":False,"empty":True})]:
    open(f"{t}/{name}.sh","w").write(fill(**kw))
PY
run() { ( cd "$T" && bash "$1.sh" "$2" >/dev/null 2>&1 ); echo $?; }
[ "$(run pass full)"     = 0 ] || fail "a fully-filled ci.sh should pass"
[ "$(run fail fast)"     != 0 ] || fail "a failing stage must fail the gate"
[ "$(run soft fast)"     != 0 ] || fail "'|| true' on a stage must NOT produce a green gate"
[ "$(run degraded full)" != 0 ] || fail "'full' with no full-only stages must not report a pass"
[ "$(run empty full)"    != 0 ] || fail "a gate with no checks must not report a pass"
[ "$FAILED" -eq "$BEFORE" ] && ok "gate refuses to report an unearned pass (5 cases)"

# --- 5. templates carry no stale paths removed in 3.0 ------------------------------------
BEFORE=$FAILED
echo "stale paths"
for p in "docs/workflow/" "\.claude/preferences/" "\.claude/project-notes/" "docs/dev/style-guide" "docs/dev/adr/" "memory/settings\.md"; do
  hits=$(git ls-files templates agents | xargs grep -l "$p" 2>/dev/null || true)
  [ -z "$hits" ] || fail "removed path '$p' still referenced in: $hits"
done
[ "$FAILED" -eq "$BEFORE" ] && ok "no references to paths removed in 3.0"

echo
if [ "$FAILED" -gt 0 ]; then
  echo "✗ self-check: $FAILED problem(s)" >&2
  exit 1
fi
echo "✓ self-check passed"
