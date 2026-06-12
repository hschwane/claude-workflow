---
name: pr
description: Create a pull request, wait for CI, run AI code/security/architecture reviews, fix findings, and auto-merge
argument-hint: "[base-branch] [\"PR description\"]"
disable-model-invocation: true
---

# PR

Creates a pull request, waits for CI to pass, runs AI code reviews, applies all findings, and auto-merges. Saves token cost by delegating mechanical checks (lint, tests, security scan) to CI.

## Usage
```
/pr
/pr develop
/pr "Optional PR description"
```

## Instructions

### 1. Pre-flight
- `git status` — working directory must be clean. If dirty: run `/commit` first.
- Identify current branch and base branch:
  - explicit argument wins
  - otherwise: `develop` if it exists (git flow — feature branches merge into develop, never directly into master)
  - otherwise: `main` / `master`
- Push the feature branch if not already pushed: `git push -u origin {branch}` (pushing feature branches is always allowed — the quality gate applies to the merge, not the push)
- Check that the branch has commits not on the base: `git log origin/{base}..HEAD --oneline`
- **Model tier for the review agents** (ask now, before the CI wait, so the user can walk away). The three reviewers are `model: inherit` agents; pass the choice as the per-invocation `model` parameter. Ask (AskUserQuestion): "Which model quality for the code/security/architecture reviews?"
  - `session-model` (recommended — name the current session model in the option label)
  - `better-than-sonnet`: pass `opus` — for large or risky diffs when the session runs Sonnet
  - `sonnet`: pass `sonnet` — saves budget when the session runs Opus/Fable and the diff is routine
  - `haiku`: pass `haiku` — not recommended; review depth (especially security) will suffer

  In unsupervised mode: skip the question, use `session-model`.

### 2. Create Pull Request
```
gh pr create --title "{branch description}" --body "{auto-generated description}" --draft
```

Auto-generate a PR description from the branch commits:
```markdown
## Summary
{One paragraph summarizing what this PR does, based on commit messages}

## Changes
{List of conventional commits on this branch}

## Spec
{Link to spec file if found in docs/specs/}

## Testing
{Brief note on what tests cover this}
```

### 3. Save Checkpoint
Determine the context file path: run `git branch --show-current | sed 's|/|-|g'` to get `{branch}`, then write to `.claude/memory/context-{branch}.md`:
```markdown
## In Progress
task: PR for {branch}
phase: pr
branch: {branch}
pr_url: {pr_url}
last_completed: "PR created (draft)"
next_step: "Wait for CI, then run code review"
saved_at: {timestamp}
```

### 4. Wait for CI — hard gate

First check whether the repository has any checks configured:
```bash
gh pr checks {pr_url}
```
If no checks exist (e.g., no CI workflow yet): note "No CI checks configured — skipping CI wait" and continue to step 5.

Otherwise, run the CI gate loop (this loop is used again after every review that pushes fixes):

```
gh pr checks {pr_url} --watch
```

**HARD RULE: Do not proceed to the next step until all CI checks pass. This applies unconditionally — not even reviews run before CI is green.**

**If CI fails:**
1. Read the failure details: `gh run view {run_id} --log-failed`
2. Diagnose and fix the issue in the code
3. Push the fix: `git add -A && git commit -m "fix(ci): {description}" && git push`
4. Return to the top of this CI gate loop — wait for CI again
5. Repeat until CI passes

After 3 consecutive fix attempts without CI going green: ask the user for help diagnosing the failure. **Do not proceed until CI passes regardless of how many attempts it takes.** Only abandon if the user explicitly instructs you to skip CI.

**If CI passes:** continue to step 5.

### 5. Code Review
Invoke the `code-reviewer` subagent (apply the model tier chosen in pre-flight) with:
- Input: `git diff origin/{base}...HEAD` (full diff)
- Input: root `CLAUDE.md` and `docs/dev/` style guides

Read the agent's report. For each `[MUST FIX]` finding:
- Fix the issue in the code
- Run: `git add -A && git commit -m "fix(review): {short description}" && git push`

If any commits were pushed, run the CI gate loop from step 4 before proceeding. Do not start the security review until CI is green.

### 6. Security Review
Invoke the `security-reviewer` subagent (apply the model tier chosen in pre-flight) with:
- Input: `git diff origin/{base}...HEAD`

For each `[CRITICAL]`, `[HIGH]`, or `[MODERATE]` finding:
- Fix the issue
- Commit and push: `git add -A && git commit -m "fix(security): {short description}" && git push`

If any commits were pushed, run the CI gate loop from step 4 before proceeding. Do not start the architect review or merge until CI is green.

### 7. Architect Review (conditional)
Only run if the diff includes:
- New files or directories in `src/`
- Changes to module exports or public interfaces
- Changes to `docs/dev/architecture.md` or ADRs

Invoke the `architect-reviewer` subagent (apply the model tier chosen in pre-flight) with:
- Input: `git diff origin/{base}...HEAD`
- Input: `docs/dev/architecture.md`
- Input: any ADRs in `docs/dev/adr/`

For each `[MUST FIX]` finding:
- Fix and push: `git add -A && git commit -m "fix(arch): {short description}" && git push`

If any commits were pushed, run the CI gate loop from step 4 before proceeding to merge. Do not merge until CI is green.

### 8. Update Checkpoint
Update the branch context file (`.claude/memory/context-{branch}.md`) with current state after each review cycle.

### 9. Final CI Confirmation + Mark PR Ready + Merge

Before merging, verify CI is currently green on the latest commit:
```bash
gh pr checks {pr_url}
```
If any check is pending or failed: run the CI gate loop from step 4 until all checks pass. **Do not convert to ready or merge with a failing or pending CI.**

Once CI is confirmed green:
- Convert draft PR to ready: `gh pr ready {pr_url}`
- Auto-merge: `gh pr merge {pr_url} --squash --auto`
  - If `--auto` fails because auto-merge is not enabled in the repo settings: merge directly with `gh pr merge {pr_url} --squash`

**Instead, ask the user before merging if ANY of these apply:**
- Merge conflicts exist
- This is a MAJOR version change (breaking API)
- The branch targets a protected branch that requires human approval

### 10. Post-Merge Cleanup
After successful merge:
- Delete local branch: `git branch -d {branch}`
- Check out base branch: `git checkout {base}`
- Pull latest: `git pull`
- If a spec file is linked (`docs/specs/ready/{id}-*.md`):
  - Update frontmatter `status: in-progress` → `status: done`
  - `git mv docs/specs/ready/{filename} docs/specs/completed/{filename}`
  - Commit: `git add docs/specs/ && git commit -m "docs(specs): complete {id}"`
- Clear the `## In Progress` section from the branch context file (`.claude/memory/context-{branch}.md`)

### 11. Report
```
PR merged ✓
{pr_url}

Reviews: code review ✓, security review ✓{, architect review ✓}
Findings fixed: {N} code, {M} security{, K architect}
Merged via: squash merge

Branch cleaned up. On {base}.
```
