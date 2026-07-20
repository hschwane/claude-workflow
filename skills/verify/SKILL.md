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

**Skip only if** you can be certain HEAD is unchanged since the last green full run in *this* session (e.g. `/verify` was just run and nothing committed since). After a `/resume` or any uncertainty, **re-run** — the repo doesn't record the last green sha, so when in doubt, run it.

### 2. Review (Claude's judgment)
Default: **self-review** — reread the diff (`git diff {integration-branch}...HEAD`) adopting a reviewer's perspective: correctness, security basics, conventions, test quality. Fix what you find.

Escalate **only for genuinely critical changes** (security-sensitive, structurally significant, high blast radius): either `/consult` the specific concern, or spawn the `reviewer` agent (best/high, fresh eyes) on the diff. Use sparingly — most changes don't need it.

### 3. Manual smoke test (new features only; skip for pure refactors/bugfixes already covered by tests)

**Map each acceptance criterion to how it's demonstrated:**
- Already covered by a passing automated test → done, cite it.
- Not covered → it needs a smoke step.
- Can't be demonstrated by either → flag it (coverage gap).

**Write the fewest smoke steps that meaningfully validate the new behavior** — as few as possible, as many as needed. Each step = an action + its **expected observable result**, derived from the criteria. Breadth is the automated tests' job; don't re-test everything here.

**You (the main session) prepare the environment — the smoke-tester never sets anything up.** Bring up the app on a **local/test instance with test data — never production**, run any needed migrations/seeds yourself, and confirm it's reachable. If it genuinely can't run locally (needs cloud services/hardware), do not skip: agree a project-specific strategy with the user (debug/staging deploy) and record it in `deploy.md`. In unsupervised mode with no such strategy on record, note it as a blocker rather than testing against prod. Use a throwaway/test database, not a dev DB you care about.

**Hand the steps to the `smoke-tester` agent** (blackbox — give it ONLY the step list + how to reach the already-running app + which tool to drive with; never the spec, criteria, or code). Remind it of its boundaries: it **drives the app through its interface and reports; it must not write/delete any project file, must not touch the database except through the app, and must not run git/build/migrations** (its agent definition enforces this). It **reports only failing steps** (expected vs observed + screenshot). If it reports "could not complete — needs setup", that's on you to prepare, then re-run — not something it should have done.

**On a reported failure:** look at the screenshot/output and decide — a real bug, a UX problem (a step a novice couldn't do either), or a limitation of the instructions. Fix bugs; note UX issues. **Every bug found here → fix it AND add an automated test** so it can't recur.

**Store the smoke steps in the spec** (a "Smoke steps" section) so they're re-runnable later. The stored copy is for reuse; the agent still runs blackbox.

### 4. Report
```
Verify ✓  {id}
Gate: green (full)   Review: {self | reviewer agent | consult}   Smoke: {N steps, all pass | M failed→fixed | n/a}
Criteria: {all demonstrated | list any flagged as undemonstrated}
{bugs found → tests added: …}
```
If something can't be made green/clean and needs a human, write `## Blocked` and stop.
