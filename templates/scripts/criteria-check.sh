#!/usr/bin/env bash
# Does this spec's criteria-verification table exist, and does it cover every criterion?
#
#   ./scripts/criteria-check.sh docs/specs/ready/FEAT-001-thing.md
#
# /verify §3 calls the criteria table "the only mechanism in the workflow that catches an
# implementation whose own tests agree with it", and forbids skipping it. Nothing enforced
# that. A session that skips §3 and reports "Criteria: 5/5 met" produces output byte-identical
# to one that did the work — which is exactly why last-gate.json exists for the weaker claim
# the gate makes.
#
# This checks SHAPE, not honesty: that the section is there and has a row per criterion. It
# cannot tell you the observed values are real. What it removes is "silently skipped" as a
# failure mode, which is all last-gate.json ever did either.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
[ -f scripts/criteria-check.sh ] || { echo "✗ criteria-check.sh: not in the repo root (cwd=$PWD)." >&2; exit 1; }

SPEC="${1:?usage: criteria-check.sh <path-to-spec.md>}"
[ -f "$SPEC" ] || { echo "✗ criteria-check.sh: no such spec: $SPEC" >&2; exit 1; }

# Body of a section, stopping at the next heading of the same level.
# awk, not a `sed` range: a sed range that finds no closing `## ` runs to EOF, and trimming its
# last line then silently drops the final table row — which for the LAST section in the file is
# always the case. That off-by-one rejected correct specs.
section() { awk -v h="## $1" '$0 == h {f = 1; next} /^## /{f = 0} f' "$SPEC"; }

# Criteria are plain bullets (the template says so explicitly: checkboxes here would leave
# every finished spec looking half-done). Ignore HTML-comment guidance lines.
CRITERIA=$(section "Acceptance Criteria" | grep -c '^[-*] ' || true)
# Table rows: pipe-delimited, minus the header and the |---|---| separator.
ROWS=$(section "Criteria verification" | grep -c '^|' || true)
[ "$ROWS" -ge 2 ] && ROWS=$((ROWS - 2)) || ROWS=0

if ! grep -q '^## Criteria verification$' "$SPEC"; then
  echo "✗ $SPEC: no '## Criteria verification' section." >&2
  echo "  /verify §3 is never skipped — build the table before marking this done." >&2
  exit 1
fi

if [ "$CRITERIA" -eq 0 ]; then
  echo "✗ $SPEC: no acceptance criteria found, so there is nothing to verify against." >&2
  echo "  A spec with no observable criteria is a spec defect — send it back to /plan." >&2
  exit 1
fi

if [ "$ROWS" -lt "$CRITERIA" ]; then
  echo "✗ $SPEC: $CRITERIA criteria but only $ROWS verification row(s)." >&2
  echo "  Every criterion needs its own row: quoted verbatim, literal expected, literal" >&2
  echo "  observed, and where the observed value came from. A criterion with no row is one" >&2
  echo "  nobody checked — which is indistinguishable from one that failed." >&2
  exit 1
fi

echo "✓ $SPEC: $CRITERIA criteria, $ROWS verification row(s)"
