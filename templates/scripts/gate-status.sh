#!/usr/bin/env bash
# Is the recorded gate result still valid for the tree in front of me?
#
#   ./scripts/gate-status.sh [full|fast]     → exit 0 = valid, skip the re-run
#                                              exit 1 = not valid, run the gate
#
# The ONE implementation of a rule that used to live as prose in four places at four
# different strengths ("passed on this exact HEAD", "known-green from this session",
# "re-run if the merge changed code"). Those paraphrases each dropped a condition, and a
# dropped condition here means skipping the authoritative gate on code it never saw.
#
# It is a comparison, not a memory: it survives a /resume, a context compaction and a
# different session, none of which "I'm fairly sure nothing changed" does.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# Fails open: with `dirname` off PATH the expansion is empty and `cd "/.."` succeeds.
[ -f scripts/gate-status.sh ] || { echo "✗ gate-status.sh: not in the repo root (cwd=$PWD)." >&2; exit 1; }

WANT="${1:-full}"
REC=".claude/memory/last-gate.json"

no() { echo "gate-status: RUN THE GATE — $1"; exit 1; }

[ -f "$REC" ] || no "no recorded result ($REC)"

field() { sed -n "s/.*\"$1\":\"\{0,1\}\([^,\"}]*\)\"\{0,1\}.*/\1/p" "$REC"; }
MODE=$(field mode); STATUS=$(field status); SHA=$(field sha); DIRTY=$(field dirty)

# 1. the recorded run must be at least as strong as the one being skipped: a `fast` result
#    never authorises skipping `full`, which is the run that adds the build and the
#    integration suites.
[ "$MODE" = "$WANT" ] || { [ "$WANT" = fast ] && [ "$MODE" = full ]; } || no "recorded mode '$MODE', need '$WANT'"
# 2.
[ "$STATUS" = passed ] || no "recorded status '$STATUS'"
# 3. same commit — or the only thing that moved since is spec bookkeeping. /implement's
#    spec-completion commit necessarily lands after the gate, and a release is not worth
#    re-gating because a checkbox was ticked. Anything outside docs/specs/ invalidates.
HEAD=$(git rev-parse --verify -q HEAD || echo unknown)
if [ "$SHA" != "$HEAD" ]; then
  CHANGED=$(git diff --name-only "$SHA..$HEAD" 2>/dev/null | grep -v '^docs/specs/' | head -1)
  [ -n "$CHANGED" ] && no "code changed since the recorded run (e.g. $CHANGED)"
  # An unreadable sha (rebased, gc'd) leaves CHANGED empty and would silently pass here.
  git cat-file -e "$SHA^{commit}" 2>/dev/null || no "recorded sha $SHA is not a commit in this repo"
fi
# 4. the tree was clean WHEN IT RAN. Without this, a gate that ran over uncommitted edits
#    which were then stashed would still look valid — it tested a tree that no longer exists.
[ "$DIRTY" = false ] || no "the recorded run was on a dirty tree"
# 5. ...and the tree is clean NOW. Not a restatement of 4: editing a file does not move HEAD,
#    so after a green clean run plus one uncommitted change all four fields above still hold.
#    This is the condition whose absence skips the gate on changed code.
[ -z "$(git status --porcelain 2>/dev/null)" ] || no "uncommitted changes in the working tree"

echo "gate-status: VALID — $MODE passed at $SHA, tree clean"
exit 0
