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
Write to `.claude/memory/context.md`:
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

### 4. Wait for CI
First check whether the repository has any checks configured for this PR (`gh pr checks {pr_url}`). If no checks exist (e.g., no CI workflow yet): note "No CI checks configured — skipping CI wait" and continue to step 5.

```
gh pr checks {pr_url} --watch
```

Poll until all required checks finish. Print status as it updates.

**If CI fails:**
- Read the failure details: `gh run view {run_id} --log-failed`
- Diagnose and fix the issue
- Push the fix
- Return to step 4 (wait for CI again)
- After 3 consecutive CI failures: pause and ask the user for guidance

**If CI passes:** continue to step 5.

### 5. Code Review
Invoke the `code-reviewer` subagent with:
- Input: `git diff origin/{base}...HEAD` (full diff)
- Input: root `CLAUDE.md` and `docs/dev/` style guides

Read the agent's report. For each `[MUST FIX]` finding:
- Fix the issue in the code
- Run: `git add -A && git commit -m "fix(review): {short description}"`

After all MUST FIX items are resolved, re-run CI if any code was changed (`gh pr checks --watch`).

### 6. Security Review
Invoke the `security-reviewer` subagent with:
- Input: `git diff origin/{base}...HEAD`

For each `[CRITICAL]`, `[HIGH]`, or `[MODERATE]` finding:
- Fix the issue
- Commit: `fix(security): {short description}`

After fixes, wait for CI again if needed.

### 7. Architect Review (conditional)
Only run if the diff includes:
- New files or directories in `src/`
- Changes to module exports or public interfaces
- Changes to `docs/dev/architecture.md` or ADRs

Invoke the `architect-reviewer` subagent with:
- Input: `git diff origin/{base}...HEAD`
- Input: `docs/dev/architecture.md`
- Input: any ADRs in `docs/dev/adr/`

For each `[MUST FIX]` finding: fix and commit.

### 8. Update Checkpoint
Update `.claude/memory/context.md` with current state after each review cycle.

### 9. Mark PR Ready + Merge
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
  - Move file: `docs/specs/ready/` → `docs/specs/completed/`
  - Commit: `git add docs/specs/ && git commit -m "docs(specs): complete {id}"`
- Clear the `## In Progress` section from `.claude/memory/context.md`

### 11. Report
```
PR merged ✓
{pr_url}

Reviews: code review ✓, security review ✓{, architect review ✓}
Findings fixed: {N} code, {M} security{, K architect}
Merged via: squash merge

Branch cleaned up. On {base}.
```
