---
name: verify
description: The verification skill — runs the gate, the review, the criteria table and the smoke test at whichever point in the workflow asked. Called at feature-done, before a merge, and before a release; /pr and /release delegate to it rather than restating checks.
argument-hint: "[ticket|pr|release] [FEAT-001] (defaults to `ticket` and the in-progress spec)"
---

# Verify

**All verification logic lives here.** `/implement` calls it at feature-done, `/pr` before a merge,
`/release` before a release. Those skills *act*; this one decides whether acting is safe. The
checks are the same in all three cases — only their depth and scope change.

## Usage
```
/verify                 # ticket mode, the in-progress spec on this branch
/verify FEAT-001        # ticket mode, that spec
/verify pr
/verify release
```
A first argument that is not `ticket`/`pr`/`release` is a ticket id, and the mode is `ticket`.

## What runs in which mode

| | `ticket` | `pr` | `release` |
|---|---|---|---|
| §1 full gate | per §1 | per §1; skipped when one ticket and nothing changed since it was verified | as `pr` |
| §2 review | whole diff | **delta since the last review** | as `pr` |
| §3 criteria table | **mandatory** | — done per ticket | — |
| §4 documentation | vs the spec's line | — | — |
| §5 smoke | §5's scope | none | regression pass in long unsupervised runs |

In `ticket` mode, resolve the spec (the argument, or the in-progress spec on this branch) and read
its **acceptance criteria** — everything below compares against them.

---

### 1. Full gate

`scripts/gate-status.sh full` decides whether it has to run. Exit 0 means the recorded result is
still valid for this exact tree and re-running proves nothing; any other exit means run it —
invoke the `runner` agent with `scripts/ci.sh full`, fix what is red, commit, repeat until green.

That script is the **only** implementation of the rule. It compares five things (recorded mode,
recorded pass, sha, recorded-clean, clean-right-now) plus the one exception, that a `docs/specs/`-only
commit since the recorded run does not invalidate it. Do not re-derive any of that here or paraphrase
it in another skill: the rule previously existed in four places at four strengths, and each
paraphrase had dropped a different condition. Two of them are easy to think redundant and are not —
recorded-clean catches a gate that ran over edits later reverted, clean-now catches an edit *after*
a green run, and editing never moves HEAD, so every other field still matches.

Read the verdict from `.claude/memory/last-gate.json` rather than the `runner`'s prose: the agent's
report is the failure excerpt, the file is the verdict.

**In `pr` and `release` mode there is one further skip:** when a single ticket was built on this
branch and nothing has changed since its `/verify` ran, the gate and the review both already cover
exactly this tree. If anything *did* change, **re-run the gate in full** — a partial re-run proves
nothing about the parts it skipped — but scope the review per §2.

### 2. Review

**Depth comes from the `review-depth` setting**, not from a judgement call made fresh each time:

| | escalate to the `reviewer` agent for |
|---|---|
| `critical-only` (default) | security-sensitive, structurally significant, high blast radius, or a value whose right answer exists outside the code |
| `critical+complex` | those, **plus** changes touching a lot of pre-existing code or with many moving parts |
| `always` | every ticket and every merge |

Below the threshold, **self-review**: reread the diff adopting a reviewer's perspective —
correctness, security basics, conventions, test quality — and fix what you find. Above it, spawn
the `reviewer` agent (fresh eyes) or `/consult` the specific concern.

**A calculation, rate, protocol or format whose right answer exists outside the code is always
critical**, whatever the setting. A wrong constant there is invisible to every other check in this
workflow and is exactly what a fresh reader holding the spec catches.

**Hand the reviewer the spec, not just the diff.** Its whole added value is an independent check
that the code produces what the *criteria* say. Given only a diff it can confirm the code is
coherent — which a wrong implementation with matching tests always is.

**Never review the same diff twice.** Record `{sha, depth}` in `.claude/memory/last-review.json`
when a review completes. Skip when the sha matches HEAD, the tree is clean, and the recorded depth
is at least the depth now required — a record made at `critical-only` does not satisfy `always`.
In `pr`/`release` mode with the sha *behind* HEAD, review only `git diff <recorded sha>..HEAD`:
review is expensive to repeat and perfectly meaningful on a delta, which is exactly why the gate's
rule is the opposite one.

### 3. Criteria verification — `ticket` mode, never skipped

**This section has no skip rule.** §5 has one; this does not. It is the only mechanism in the
workflow that catches an implementation whose own tests agree with it, so a ticket phrased as a
refactor gets the table exactly like any other.

One row per criterion, four columns:

| Criterion (quoted verbatim, + `spec.md:LINE`) | Literal expected value | Literal observed value | Where the observed value came from |
|---|---|---|---|

Both values quoted verbatim. The first column exists so a reader can diff your expected value
against the spec **without trusting you** — a table whose expected column was quietly copied from
the code's output is otherwise indistinguishable from a correct one.

| Outcome | What it takes |
|---|---|
| **Met** | Observed literal equals expected literal, from a run you performed or from a test **that asserts the criterion's own expected value** — quote the assertion. "Covered by a passing test" is not evidence: a test written from the same wrong model as the code passes. If the test asserts something else, treat the criterion as not covered and run it. |
| **Not covered** | Implemented but nothing asserts the value → it needs a smoke step in §5. |
| **UNMET → verify FAILS** | Not implemented, stubbed, "deferred", silently narrowed, **or the observed literal differs**. Not a flag — the ticket is not done. Back to `/implement`, or `/consult`, or `## Blocked`. A criterion is never satisfied by deferring it. |
| **Undemonstrable** | Impossible to demonstrate *because of the environment* (hardware, an unreachable third-party sandbox) → say so, with why, and pass. **Not** applicable when it is undemonstrable because the criterion never said what to compare against — that is a spec defect, back to `/plan`. |

**The expected column comes from the spec. Full stop.** Never from the code, the tests, or a run —
not even to "check what format it prints in". The moment you read the implementation to decide what
the answer should be, the table certifies that the code agrees with itself, which it always does.

**Check the oracle, not just the criteria.** A criterion whose expected value was computed from the
same model the code implements is self-referential. Before signing off on anything with a right
answer outside the code, confirm the spec says where its expected values came from, that at least
one criterion is anchored to something independent, and — where the spec carries two anchors —
**spot-check that they are mutually consistent**. Two published pairs cannot both hold under a wrong
constant, which is the one check that catches a plausible citation of a wrong value. No such source
is a `[MUST FIX]`-shaped finding: report it and raise a follow-up ticket. Same for **unsourced
constants and seed data** the ticket introduced.

**Store the table in the spec under `## Criteria verification`,** then run
`scripts/criteria-check.sh <spec>` — it fails on a missing section or a criterion with no row.
A judgment reported in chat evaporates at the end of the turn. Record the first pass, including any
row that failed and what you did about it: a spec showing "row 2 failed, constant corrected, re-run
green" is worth far more than one asserting everything passed.

### 4. Documentation — `ticket` mode

Check the spec's `## Documentation impact` line was honoured. `None.` means there is nothing to
check. Otherwise: the named docs are updated, and a new `docs/dev/` document has its row in
`docs/dev/README.md` — an unindexed dev doc is one nothing will find. If the implementation turned
out to introduce a contract the line did not foresee — an algorithm, a format, an interface, a
protocol — that is a finding, not a silent fix: say so and write it.

### 5. Manual smoke test

Run it for anything a user can observe. Skip only for a change with **no user-visible surface** — an
internal refactor, a dependency bump — or behaviour already covered by tests written *before this
ticket started*. A bug fix shipping its own regression test does **not** qualify: those tests came
from the same session as the fix, so they prove the code does what the author intended, not what the
user asked for. **The skip applies to §5 only — never to §3.**

**Scope:**
- **1–3 steps for the main story**, as the ticket describes and intends it;
- **one step per acceptance criterion**;
- **more where they earn it** — interactions between criteria, or areas of the project this change
  could plausibly have disturbed.

**Intensity scales with risk and autonomy.** More manual testing the larger, more complex or more
critical the change — and the more autonomously the work is running. A long unsupervised run with
many tickets gets the full scope every ticket; a small bugfix with the user watching gets little or
nothing, and a trivial one gets none. Automation removes the human who would otherwise have noticed
something odd in passing, so the less supervision a run has, the more deliberately that attention
has to be bought back. Same judgement axis as `review-depth`.

**Each step is a concrete, executable test case — not a goal.** The agent is blackbox: it never sees
the spec, the criteria or the code, and it **makes no judgement calls**. It does not decide whether
a near-match counts, or whether a difference matters. Observed ≠ expected is a failure. So anything
left implicit is lost, and a step needing interpretation comes back as could-not-complete. Every
step needs:
- an **exact action** with **literal inputs** — the precise URL or command, the exact values to
  type, the control to click by its visible label, the test credentials. Not "log in" but "open
  `http://localhost:3000/login`, type `test@example.com` / `pw123`, click **Sign in**".
- an **exact, observable expected result** — a specific visible string, element, route, status code
  or output. Not "the dashboard loads" but "lands on `/dashboard` and shows **Welcome, test**". If a
  human could not tell pass from fail by reading your step, neither can the agent.
- **derived from the acceptance criterion, never from the code or its output.** Running the tool,
  seeing what it prints and writing that down produces a smoke run that passes against any
  implementation, including a wrong one.
- **a fixed expected result.** A step can be observable and still non-deterministic — "the answer is
  in the future", "the newest item is first" — and pass on a broken build because of when the clock
  happened to be. Pin the inputs: an explicit timestamp, a seeded fixture.

**You prepare the environment; the smoke-tester never sets anything up.** `scripts/dev.sh` brings up
the dev environment with test data and `scripts/dev.sh --info` prints the URL and test credentials —
hand that output to the agent verbatim as `HOW_TO_RUN`. Start it before handing off and stop it right
after. **Never production**, and a throwaway database, not a dev one you care about. If the change
genuinely cannot run locally, agree a strategy with the user and record it in `deploy.md`; in
unsupervised mode with none on record, note it as a blocker rather than testing against prod.

**Hand the agent only** the resolved steps, that `HOW_TO_RUN`, and which tool to drive with — never
the spec, the criteria or the code. It reports per-step evidence plus detail on failures.

**On a reported failure:** decide — a real bug, a UX problem (a step a novice could not do either),
or a limitation of your instructions. Fix bugs; note UX issues. **Every bug found here → fix it AND
add an automated test** so it cannot recur.

**Store the steps in the spec** under `## Smoke steps` so they are re-runnable. That, not a stored
result, is the record: re-running them answers "does it still work?", which a past claim cannot.

**In `release` mode**, a long unsupervised run gets a second pass here over the combined state —
the new features **and** the important older ones. It is the only human-shaped check the merged
result ever gets, since every ticket was verified alone, before the others existed.

### 6. Report
```
Verify ✓  {mode}{ · id}
Gate: {green (full) | skipped — valid for this sha}   Review: {self | reviewer | consult | skipped — same sha}
Criteria: {N/N met — table in <spec>#criteria-verification | FAIL — unmet: <list> → back to /implement}
          {any row that failed on the first pass, and what fixed it}
Docs: {done per spec | none required}   Smoke: {N steps, all pass | M failed→fixed | n/a}
{bugs found → tests added: …}
```
If something cannot be made green and needs a human, write `## Blocked` and stop.
