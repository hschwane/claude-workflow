---
name: verify
description: Feature-done QA — run the full gate, review (self or agent), and a blackbox manual smoke test of a new feature, then report. Proves the change works and matches its acceptance criteria. Invoked by /implement and /ship; also runnable directly.
argument-hint: "[FEAT-001] (defaults to the in-progress spec on this branch)"
---

# Verify

The "feature done" quality step. Confirms a change (a) passes the full automated gate, (b) survives review, and (c) actually does what its acceptance criteria say when run for real. Automated tests carry the breadth; the manual smoke test is a small, blackbox discovery pass over the *new* behavior.

## Usage
```
/verify            # verifies the in-progress spec on the current branch
/verify FEAT-001
```

## Instructions

Resolve the spec: the argument, or the in-progress spec on the current branch. Read its **acceptance criteria**.

### 1. Full gate
Invoke the `runner` agent with `scripts/ci.sh full` (format + lint + typecheck + **all** automated tests incl. integration/e2e + the deployable build). Fix anything red, commit the fix, re-run until green. This is the authoritative correctness gate.

**Skip only if the recorded result says you may.** `ci.sh` writes `.claude/memory/last-gate.json` — `{mode, status, checks, full_checks, failed, sha, dirty}`. Skip the re-run only when **all five** hold:
  1. the file says `"mode":"full"`,
  2. and `"status":"passed"`,
  3. and its `sha` equals `git rev-parse HEAD`,
  4. and it says `"dirty":false`,
  5. **and `git status --porcelain` is empty right now.**

  (5) is not a restatement of (4). The record is a snapshot taken *before* any later edit, so after a green clean run plus one uncommitted change all four recorded fields still hold — HEAD does not move when a file is edited. Checking only the JSON skips the authoritative gate on changed code, which is the precise failure this paragraph exists to prevent. The fourth is not optional — uncommitted edits do not move HEAD, so without it the one path that skips the authoritative gate is reachable on a tree whose code has changed since the green run. That is a comparison, not a memory: it survives a `/resume`, a context compaction and a different session, all of which "I'm fairly sure nothing changed" does not.

No file, a different sha, or any other status → **run it**. And read the file yourself rather than taking the `runner`'s word for the outcome: the agent's prose is the failure excerpt, this is the verdict.

### 2. Review (Claude's judgment)
Default: **self-review** — reread the diff (`git diff {integration-branch}...HEAD`) adopting a reviewer's perspective: correctness, security basics, conventions, test quality. Fix what you find.

Escalate **only for genuinely critical changes** (security-sensitive, structurally significant, high blast radius, **or a calculation, rate, protocol or format whose right answer exists outside the code** — a wrong constant there is invisible to every other check and is exactly what a fresh reader with the spec catches): either `/consult` the specific concern, or spawn the `reviewer` agent (best/high, fresh eyes). Use sparingly — most changes don't need it.

**Hand the reviewer the spec, not just the diff.** Its whole added value over your own read is an independent check that the code produces what the *criteria* say; given only a diff it can confirm the code is coherent, which a wrong implementation with matching tests always is.

**Check the oracle, not just the criteria.** A criterion whose expected value was computed from the same model the code implements is self-referential: it passes because the code agrees with itself. Before signing off on a feature with a right answer that exists outside the code — a calculation, a rate, a protocol, a format — confirm the spec says where its expected values came from, that at least one criterion is anchored to something independent, and — where the spec carries two anchors — **spot-check that they are mutually consistent**. Two published pairs cannot both hold under a wrong constant, so this is the one check that can catch a plausible-looking citation of a wrong value; confirming the spec merely *has* provenance cannot. If the spec has no such source, that is a `[MUST FIX]`-shaped finding: report it and, unless the user says otherwise, raise a follow-up ticket. Do not record it as verified on the strength of internal consistency alone.

Same for **unsourced constants and seed data** the ticket introduced: if a magic number or a reference table arrived without a citation, say so in the report.

### 3. Criteria verification — always, no exceptions

**This section is never skipped.** The smoke run in §4 has a skip rule; this table does not. It is the only mechanism in the workflow that catches an implementation whose own tests agree with it, so a ticket phrased as a refactor gets the table exactly like any other.

Build a table with one row per criterion and **four columns**:

| Criterion (quoted verbatim, + `spec.md:LINE`) | Literal expected value | Literal observed value | Where the observed value came from |
|---|---|---|---|

Both values are quoted verbatim. The first column exists so a reader can diff your expected value against the spec **without trusting you** — a table whose expected column was quietly copied from the code's output is otherwise indistinguishable from a correct one, and that forgery is the residual hole this column closes.

| Outcome | What it takes |
|---|---|
| **Met** | The observed literal equals the expected literal. The observed value comes from a run you performed, or from an automated test **that asserts the criterion's own expected value** — quote the assertion. "Covered by a passing test" is *not* evidence on its own: a test written from the same wrong model as the code passes, and citing it certifies nothing. If the test asserts something other than the criterion's literal, treat the criterion as not test-covered and run it. |
| **Not covered** | Implemented but nothing asserts the criterion's value → it needs a smoke step in §4. |
| **UNMET → verify FAILS** | Not implemented, stubbed, "deferred", silently narrowed, **or the observed literal differs from the expected one**. This is not a "flag" — the ticket is not done. Go back to `/implement` and build it (or `/consult`, or `## Blocked` if it truly needs a human). A criterion is never satisfied by deferring it. |
| **Undemonstrable** | Genuinely impossible to demonstrate *because of the environment* (needs hardware, a third-party sandbox you cannot reach) → note it explicitly with why, and pass. **Not** applicable when it is undemonstrable because the criterion never said what to compare against — that is a spec defect: send it back to `/plan`. |

**The expected column comes from the spec. Full stop.** Never from the code, the tests, or a run — not even to "check what format it prints in". The moment you read the implementation to decide what the answer should be, this table certifies that the code agrees with itself, which it always does. Tests and runs supply the **observed** column only. If a criterion's expected value is missing or unusable, that is a finding about the spec, not a gap to fill from the output.

**Store the table in the spec, under `## Criteria verification`.** A judgment reported in chat evaporates at the end of the turn; the point of a table is that someone can audit it later. Record the first pass, including any row that failed and what you did about it — a spec showing "row 2 failed, constant corrected, re-run green" is worth far more than one asserting everything passed.

### 4. Manual smoke test

Run it for anything a user can observe. Skip it only for a change with **no user-visible surface** — an internal refactor, a dependency bump — or one whose behavior was already covered by tests *before this ticket started*. A bug fix that ships its own regression test does **not** qualify: those tests were written by the same session that wrote the fix, so they prove the code does what the author intended, not what the user asked for. That is the gap the smoke run exists to close. **This skip applies to the smoke steps only — never to §3's table.**

**Write the fewest smoke steps that meaningfully validate the new behavior** — as few as possible, as many as needed. Breadth is the automated tests' job; don't re-test everything here.

**Each step must be a concrete, executable test case — not a goal.** The agent is blackbox: it never sees the spec, the criteria, or the code, so anything you leave implicit is simply lost, and a vague step comes back as "could not complete" (or a false pass). Every step needs:
- an **exact action** with the **literal inputs** — the precise URL/route or command, the exact values to type, which control to click by its visible label, the test credentials to use. Not "log in" but "open `http://localhost:3000/login`, type `test@example.com` / `pw123`, click **Sign in**".
- an **exact, observable expected result** — a specific visible string, element, route, status code, or output. Not "it works" or "the dashboard loads" but "lands on `/dashboard` and shows the text **Welcome, test**". If a human couldn't tell pass from fail by reading your step, the agent can't either.

- **derived from the acceptance criterion, never from the code or its output.** This is the same rule as the mapping table above, and it is the step most often broken: running the tool, seeing what it prints and writing that down as the expected result produces a smoke run that passes against any implementation, including a wrong one. Take the expected string from the criterion.
- **a fixed expected result.** A step can be perfectly observable and still non-deterministic — "the answer is in the future", "the newest item is first" — and pass against a broken build because of when the clock happened to be. Pin the inputs: an explicit timestamp, a seeded fixture. A step that only detects the bug half the time reports a pass you will trust.

Hand the agent only the resolved, unambiguous steps.

**You (the main session) prepare the environment — the smoke-tester never sets anything up.** Bring up the app on a **local/test instance with test data — never production**, run any needed migrations/seeds yourself, and confirm it's reachable. If it genuinely can't run locally (needs cloud services/hardware), do not skip: agree a project-specific strategy with the user (debug/staging deploy) and record it in `deploy.md`. In unsupervised mode with no such strategy on record, note it as a blocker rather than testing against prod. Use a throwaway/test database, not a dev DB you care about.

**Hand the steps to the `smoke-tester` agent** (blackbox — give it ONLY the step list + how to reach the already-running app + which tool to drive with; never the spec, criteria, or code). Remind it of its boundaries: it **drives the app through its interface and reports; it must not write/delete any project file, must not touch the database except through the app, and must not run git/build/migrations** (its agent definition enforces this). It **reports only failing steps** (expected vs observed + screenshot). If it reports "could not complete — needs setup", that's on you to prepare, then re-run — not something it should have done.

**On a reported failure:** look at the screenshot/output and decide — a real bug, a UX problem (a step a novice couldn't do either), or a limitation of the instructions. Fix bugs; note UX issues. **Every bug found here → fix it AND add an automated test** so it can't recur.

**Store the smoke steps in the spec** (a "Smoke steps" section) so they're re-runnable later. The stored copy is for reuse; the agent still runs blackbox.

### 5. Report
```
Verify ✓  {id}
Gate: green (full)   Review: {self | reviewer agent | consult}   Smoke: {N steps, all pass | M failed→fixed | n/a}
Criteria: {N/N met — table in <spec>#criteria-verification | FAIL — unmet: <list> → back to /implement}
          {any row that failed on the first pass, and what fixed it}
{bugs found → tests added: …}
```
If something can't be made green/clean and needs a human, write `## Blocked` and stop.
