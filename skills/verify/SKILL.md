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

**Every acceptance criterion must actually be met — this is the gate against a half-built ticket.** Map each one:
- Implemented + covered by a passing automated test → done, cite it.
- Implemented but not test-covered → needs a smoke step to demonstrate it.
- **Not implemented / stubbed / "deferred" / silently narrowed → verify FAILS.** This is not a "flag" — the ticket is not done. Go back to `/implement` and build it (or `/consult`, or `## Blocked` if it truly needs a human). A criterion is never satisfied by deferring it.
- Implemented and clearly correct but genuinely impossible to demonstrate by test or smoke (rare) → note it explicitly with why.

**Write the fewest smoke steps that meaningfully validate the new behavior** — as few as possible, as many as needed. Breadth is the automated tests' job; don't re-test everything here.

**Each step must be a concrete, executable test case — not a goal.** The agent is blackbox: it never sees the spec, the criteria, or the code, so anything you leave implicit is simply lost, and a vague step comes back as "could not complete" (or a false pass). Every step needs:
- an **exact action** with the **literal inputs** — the precise URL/route or command, the exact values to type, which control to click by its visible label, the test credentials to use. Not "log in" but "open `http://localhost:3000/login`, type `test@example.com` / `pw123`, click **Sign in**".
- an **exact, observable expected result** — a specific visible string, element, route, status code, or output. Not "it works" or "the dashboard loads" but "lands on `/dashboard` and shows the text **Welcome, test**". If a human couldn't tell pass from fail by reading your step, the agent can't either.

Derive these concretes from the acceptance criteria yourself (that's your job as the sighted caller); hand the agent only the resolved, unambiguous steps.

**You (the main session) prepare the environment — the smoke-tester never sets anything up.** Bring up the app on a **local/test instance with test data — never production**, run any needed migrations/seeds yourself, and confirm it's reachable. If it genuinely can't run locally (needs cloud services/hardware), do not skip: agree a project-specific strategy with the user (debug/staging deploy) and record it in `deploy.md`. In unsupervised mode with no such strategy on record, note it as a blocker rather than testing against prod. Use a throwaway/test database, not a dev DB you care about.

**Hand the steps to the `smoke-tester` agent** (blackbox — give it ONLY the step list + how to reach the already-running app + which tool to drive with; never the spec, criteria, or code). Remind it of its boundaries: it **drives the app through its interface and reports; it must not write/delete any project file, must not touch the database except through the app, and must not run git/build/migrations** (its agent definition enforces this). It **reports only failing steps** (expected vs observed + screenshot). If it reports "could not complete — needs setup", that's on you to prepare, then re-run — not something it should have done.

**On a reported failure:** look at the screenshot/output and decide — a real bug, a UX problem (a step a novice couldn't do either), or a limitation of the instructions. Fix bugs; note UX issues. **Every bug found here → fix it AND add an automated test** so it can't recur.

**Store the smoke steps in the spec** (a "Smoke steps" section) so they're re-runnable later. The stored copy is for reuse; the agent still runs blackbox.

### 4. Report
```
Verify ✓  {id}
Gate: green (full)   Review: {self | reviewer agent | consult}   Smoke: {N steps, all pass | M failed→fixed | n/a}
Criteria: {ALL met and demonstrated | FAIL — unmet: <list> → back to /implement}
{bugs found → tests added: …}
```
If something can't be made green/clean and needs a human, write `## Blocked` and stop.
