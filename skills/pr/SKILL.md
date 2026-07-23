---
name: pr
description: Open a pull request for the current branch — optional utility for external review or collaboration. NOT part of the default flow (which merges locally per the Merge policy). Use when a human should review, or the repo requires PRs.
argument-hint: "[base branch]"
---

# PR (optional)

The default flow **merges locally** with plain git (see the Merge policy in `CLAUDE.md` / `docs/workflow/lifecycle.md`) and does not open PRs. Use `/pr` only when you explicitly want one: a human reviewer, an open-source contribution flow, or a repo whose branch protection requires PRs.

## Usage
```
/pr              # base = integration branch (develop if it exists, else main/master)
/pr main
```

## Instructions

### 1. Pre-flight
- Ensure the branch's work is done and its gate is green (`/verify` has run). If not, do that first.
- Ensure the branch is pushed and up to date with the base: `git fetch origin {base} && git merge origin/{base} --no-edit` (resolve conflicts locally; re-run the gate if the merge changed code).

### 2. Create the PR
- Look for a PR template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/…`, `docs/…`). If one exists, populate its sections; otherwise write a concise body: what changed, why, how it was verified (gate + `/verify` result), and any deferred-scope notes.
- `gh pr create --base {base} --head {branch} --title "{type}({scope}): {summary}" --body-file {body}`.

### 3. Review
- **Default: rely on the local `/verify` already done** — self-review + smoke happened there.
- For a genuinely critical change, spawn the `reviewer` agent (best/high) on `git diff origin/{base}...HEAD`, or `/consult` a specific concern. Address `[MUST FIX]` findings, push, re-verify. `[CONSIDER]`/`[ADR NEEDED]` are report-only.
- If the PR carries **user-facing behavior that no smoke test exercised** (e.g. `/verify` ran but the change is worth showing a reviewer working), it's worth a quick blackbox pass: bring up a local/test instance and hand the `smoke-tester` a few steps, so the PR body can state it was manually confirmed. Skip for pure internal/refactor changes already covered by the gate.

### 4. CI (only if it actually runs)
Claude's commits carry `[skip ci]`, so **CI usually does not run on this PR** — don't wait for checks that will never report (a skipped required check sits Pending forever). Only when the project is `ci-on-claude: yes` **and** CI is running: arm `subscribe_pr_activity` once and end the turn; act on failures when the webhook wakes you. Never sleep-poll `gh pr checks`.

### 5. Merge
Once review is satisfied (and CI green if it ran): `gh pr merge --squash`. Set the squash commit message explicitly and append `[skip ci]` unless `ci-on-claude: yes`, so the squashed commit landing on the base doesn't re-trigger CI. **Don't use `--auto` expecting a `[skip ci]` check to report** — a skipped required check sits Pending forever; if branch protection blocks the merge on a stuck check, that protection config is the problem to fix (this scheme assumes CI is not a required check).

Ask before merging when: a merge conflict needed non-trivial resolution, the change is a major/breaking version, or the base branch requires human approval.

### 6. Report
PR URL, review outcome, merge state.
