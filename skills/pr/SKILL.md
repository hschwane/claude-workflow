---
name: pr
description: Create a pull request, wait for CI, run AI code/security/architecture reviews, fix findings, and auto-merge
argument-hint: "[base-branch] [\"PR description\"]"
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
- **Determine the review tier** (no question — derived from the specs in the diff):
  - Collect the spec files touched by or linked to this branch (`docs/specs/**` in the diff, or the checkpoint's spec pointer) and read each spec's `routing.refinement`.
  - **Single ticket** → review tier = that ticket's `routing.refinement` (e.g. `opus-high`).
  - **Multiple tickets, or a release-integration PR** (e.g. develop → master) → review tier = `opus-medium` (bulk reviews run cheaper; the per-ticket gates already ran at full tier). Exception for security-sensitive paths: see step 6.
  - No spec found (ad-hoc branch), or the spec predates routing (no/empty `routing:` block) → `sonnet-high` for small routine diffs, `opus-high` otherwise.
  - State the chosen tier in one line. The tier's **model** is passed per-invocation to the three reviewers; its **effort** is applied by invoking the matching route skill immediately before the review phase (step 4b) — not now, so the CI wait stays on the cheap session model.

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

{If the spec has `github_issue` set: add a final line `Closes #{github_issue}` — GitHub will auto-close the issue on merge}
```

### 3. Save Checkpoint
Determine the context file path: run `git branch --show-current | sed 's|/|-|g'` to get `{branch}`, then write to `.claude/memory/context-{branch}.md`:
```markdown
## In Progress
task: PR for {branch}
phase: pr
branch: {branch}
pr_url: {pr_url}
tier: {review tier from pre-flight — /resume re-arms it before the review phase}
last_completed: "PR created (draft)"
next_step: "Wait for CI, then run code review"
saved_at: {timestamp}
```

### 3b. Spec-Only Diff Check

Run:
```bash
git diff --name-only origin/{base}...HEAD | grep -v "^docs/specs/" | head -1
```

If this outputs **nothing** — every changed file in this branch is under `docs/specs/` — take the spec-only fast path:
- Skip step 4 (CI wait)
- Skip step 5 (code review), step 6 (security review), step 7 (architect review)
- Verify once more immediately before merging: re-run the same command and confirm it is still empty
- Proceed directly to step 9 (merge) — the "ask before merging" conditions in step 9 still apply

**Only use this path if you are 100% certain the entire diff is within `docs/specs/`.** Any non-spec file in the diff → run the full PR flow with CI and reviews.

### 4. Wait for CI — hard gate

First check whether the repository has any checks configured:
```bash
gh pr checks {pr_url}
```
If no checks exist (e.g., no CI workflow yet): note "No CI checks configured — skipping CI wait" and continue to step 4b (the review scope triage still applies — repos without CI need the reviews most).

Otherwise, run the CI gate loop (this loop is used again after every review that pushes fixes):

Poll every 30 seconds with separate Bash calls — do **not** use `--watch` (it blocks in a single tool call and prevents the usage threshold hook from firing):
```bash
gh pr checks {pr_url}
```
Repeat until all checks show `pass`, or at least one shows `fail`. Each poll is a separate tool call so the usage guard can check between polls.

> **Polling in cloud/remote sessions** — applies to EVERY polling loop in this skill (this CI gate, the merge wait in step 9, the post-merge CI check in step 10b). If a schedule-a-future-message tool is available (e.g. `send_later` from the Claude Code Remote MCP server, or `ScheduleWakeup`), this is a managed session without an attached terminal. Do **not** sleep between polls and do **not** use `--watch`/`gh run watch` — a Bash sleep loop burns turns and can hit the session limit before CI even finishes.
>
> **Arm TWO independent wake signals so a single missed wake never strands the session** (the known failure mode: the session ends the turn but never wakes back up):
> 1. **Event subscription (the load-bearing signal):** the first time you reach this gate, call `subscribe_pr_activity` for `{pr_url}` (idempotent — safe to call once). CI **failures** and review comments then arrive as `<github-webhook-activity>` messages that wake the session on their own. This is the more robust path because it is armed **once** and the harness pushes the events — it needs **no re-arming**, so it keeps working even in a woken session that lacks the scheduling tools.
> 2. **Scheduled self-check-in (fallback, always in addition):** webhooks do **not** deliver CI *success*, new pushes, or merge-conflict transitions — so also schedule a self-check-in a few minutes out (e.g. "Continue /pr for `{pr_url}`: re-check CI / merge state") every time you end a waiting turn. Caveat: this must be **re-armed on every wake**, so it only survives if `send_later`/`ScheduleWakeup` is in the woken session's tool allowlist (see note below) — which is exactly why the subscription in (1) is the primary signal and this is only the fallback.
>
> Then **end the turn** — never end a waiting turn without at least one signal armed (prefer both). On each wake (from either signal): re-check `gh pr checks {pr_url}`; act on the result; if still pending, re-arm the scheduled self-check-in and end the turn again. Repeat until the gate's terminal condition (CI green, or the merge/post-merge check completes). Because two independent mechanisms are armed, a dropped webhook OR a missed scheduled wakeup still leaves the other to resume the work.
>
> **Allowlist dependency:** in cloud sessions the `send_later`/`subscribe_pr_activity` tools must be in the session's permission allowlist to be callable on each wake. The plugin's `templates/hooks/hooks.json` (a project's `.claude/settings.json`) ships them pre-allowed under `permissions.allow` (`mcp__Claude_Code_Remote__*`); if a scheduled wake can't call them, verify that block survived into the project and that the "Claude Code Remote" connector is selected for the session/routine in the web UI.
>
> If NO schedule-a-future-message tool is available (local session with an attached terminal), fall back to polling every 30 seconds with separate Bash calls (still never `--watch`).

**Use the wait productively (queued work only):** if this run has more tickets queued (multi-ticket `/ship` or an explicit work order) and CI is still pending, advance the **next ticket's work** instead of idling — its refinement if still missing, or (in a `/ship` pipeline) its implementation on its **own** feature branch. Never make code changes on this PR's branch while its CI runs. Mechanics: working tree must be clean → `git checkout {base}` → continue the next ticket per its skill (own branch, own checkpoint, own `tier:`) → return to `{branch}` before re-checking CI or ending the turn. A CI failure always takes priority: switch back and fix first; the interrupted work resumes later from its checkpoint.

**HARD RULE: Do not proceed to the next step until all CI checks pass. This applies unconditionally — not even reviews run before CI is green.**

**If CI fails:**
1. Read the failure details: `gh run view {run_id} --log-failed`
2. Diagnose and fix the issue in the code
3. Push the fix: `git add -A && git commit -m "fix(ci): {description}" && git push`
4. Return to the top of this CI gate loop — wait for CI again
5. Repeat until CI passes

After 3 consecutive fix attempts without CI going green: ask the user for help diagnosing the failure. **Do not proceed until CI passes regardless of how many attempts it takes.** Only abandon if the user explicitly instructs you to skip CI.

**If CI passes:** continue to step 4b.

### 4b. Review Scope Triage

Scale review effort to the diff's size and risk:

```bash
git diff --stat origin/{base}...HEAD | tail -1     # total changed lines
git diff --name-only origin/{base}...HEAD
```

Check the file list for **security-sensitive paths**: authentication/session/crypto/secrets code, `.env*`, dependency manifests and lockfiles, network request handling, SQL/database queries or migrations, child-process/exec/eval, deserialization, file-upload or path handling, permission/ACL logic. **When unsure whether a file is sensitive, treat it as sensitive.**

- **Light review** — fewer than ~200 changed lines AND no security-sensitive files: run ONLY step 5 (code review). Skip steps 6 and 7.
- **Full review** — everything else: run steps 5, 6, and 7 (architect review still conditional per its own criteria). A diff touching security-sensitive files gets the dedicated security review **regardless of size**.

**Apply the review tier now:** invoke the route skill matching the tier determined in pre-flight (e.g. `route-opus-high`, or `route-opus-medium` for bulk PRs) — reviews and the judgment on their findings run on this tier. After the last review of this turn completes (before the merge-wait phases), invoke `route-sonnet-medium` to step back down.

**Deferred-findings policy** (governs steps 5–7 below; tunable via `/workflow-decisions` — see `docs/workflow/decisions.md`):
- **Light-review path** (small, single-feature diff): also fix `[SUGGESTION]` findings immediately, same as `[MUST FIX]` — the diff is small enough that fixing them costs little and there's no later full review to catch them if deferred.
- **Full-review path** (larger or bundled diff): `[SUGGESTION]` / `[INFO]` findings are report-only — list them in the final report (step 11), do not fix.
- `[CONCERN]` and `[ADR NEEDED]` from the architect review are **always** report-only regardless of path — they call for a human architectural judgment, not a mechanical fix.

**Crash-safe dispatch (steps 5–7).** Reviewers are read-only — their findings live only in context, so a crash mid-review loses them. Before invoking each reviewer, add it to the checkpoint's `subagents:` block (`agent: {reviewer}`, `status: dispatched`, no `output`); after you have read its report and applied/deferred its findings, flip that entry to `done`. If the turn is interrupted, `/resume` step 4a re-dispatches only the reviewer(s) still `dispatched`.

### 5. Code Review
Invoke the `code-reviewer` subagent (pass the review tier's model per-invocation) with:
- Input: `git diff origin/{base}...HEAD` (full diff)
- Input: root `CLAUDE.md` and `docs/dev/` style guides
- If step 4b chose the light path, add: *"You are the only reviewer for this small, low-risk diff — also check security basics (injection, secrets in code, unsafe input handling) and structural fit."*

Read the agent's report. For each `[MUST FIX]` finding:
- Fix the issue in the code
- Run: `git add -A && git commit -m "fix(review): {short description}" && git push`

Apply the deferred-findings policy from step 4b to each `[SUGGESTION]` finding:
- **Light-review path:** fix it too, in the same commit(s) as the MUST FIX fixes.
- **Full-review path:** carry it forward (file, line, description) into the deferred-findings list for the final report (step 11) — do not fix it, do not drop it.

If any commits were pushed, run the CI gate loop from step 4 before proceeding. Do not start the security review until CI is green.

### 6. Security Review (skipped on the light-review path — see 4b)
On a bulk PR (armed at `route-opus-medium`) whose diff touches security-sensitive paths: invoke `route-opus-high` before this review, and re-arm `route-opus-medium` afterwards if the architect review still runs — security findings deserve full depth even on bulk diffs.

Invoke the `security-reviewer` subagent (pass the review tier's model per-invocation) with:
- Input: `git diff origin/{base}...HEAD`

For each `[CRITICAL]`, `[HIGH]`, or `[MODERATE]` finding:
- Fix the issue
- Commit and push: `git add -A && git commit -m "fix(security): {short description}" && git push`

Carry forward every `[INFO]` finding (file, line, description) into the deferred-findings list for the final report (step 11) — do not fix these, do not drop them.

If any commits were pushed, run the CI gate loop from step 4 before proceeding. Do not start the architect review or merge until CI is green.

### 7. Architect Review (conditional; skipped on the light-review path — see 4b)
Only run if the diff includes:
- New files or directories in `src/`
- Changes to module exports or public interfaces
- Changes to `docs/dev/architecture.md` or ADRs

Invoke the `architect-reviewer` subagent (pass the review tier's model per-invocation) with:
- Input: `git diff origin/{base}...HEAD`
- Input: `docs/dev/architecture.md`
- Input: any ADRs in `docs/dev/adr/`

For each `[MUST FIX]` finding:
- Fix and push: `git add -A && git commit -m "fix(arch): {short description}" && git push`

Carry forward every `[CONCERN]` and `[ADR NEEDED]` finding (file/area, description) into the deferred-findings list for the final report (step 11) — do not fix these, do not drop them.

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

**Wait for the merge to actually complete** — with `--auto` the merge is asynchronous. Poll until the PR state is `MERGED`:
```bash
gh pr view {pr_url} --json state -q .state
```
Check every 30 seconds (cloud/remote sessions: use the scheduled-wakeup pattern from step 4 instead of sleeping). If not merged after 10 minutes: report to the user and stop.

### 10. Post-Merge Cleanup
After successful merge:
- Check out base branch: `git checkout {base}`
- Pull latest: `git pull`
- Delete local branch: `git branch -D {branch}` (`-D` is required: after a squash merge the branch is not an ancestor of {base}, so `-d` refuses)
- If a spec file is linked:
  - Check `docs/specs/ready/{id}-*.md` — if it still exists there (not yet moved by `/implement`): update frontmatter `status` → `done`, `git mv` to `docs/specs/completed/`, commit `docs(specs): complete {id}`
  - If it is already in `docs/specs/completed/` (moved by `/implement`): nothing to do
- Clear the `## In Progress` section from the branch context file (`.claude/memory/context-{branch}.md`)

### 10b. Post-Merge CI Check

After `git pull` on the base branch, verify that the CI triggered by the merge commit also passes:

```bash
MERGE_SHA=$(git rev-parse HEAD)
gh run list --branch {base} --commit "$MERGE_SHA" --limit 5
```

If no runs appear within 60 seconds (repo may not attach runs to merge SHAs), fall back to:
```bash
gh run list --branch {base} --limit 3
```

**If runs are found:** poll every 30 seconds with separate Bash calls until finished — do not use `gh run watch` (blocks in a single tool call); cloud/remote sessions: use the scheduled-wakeup pattern from step 4 instead of sleeping:
```bash
gh run view {run_id} --json status,conclusion -q '[.status, .conclusion]'
```
Repeat until `status` is `completed`.

**If a run fails:**
1. Read the logs: `gh run view {run_id} --log-failed`
2. Diagnose and fix:
   - **Simple fix** (typo, missing env var, trivial config): commit directly to `{base}` and push
   - **Non-trivial fix**: create a new branch, open a new `/pr`, do not push directly to `{base}`
3. Push and re-check:
   ```bash
   git push origin {base}
   gh run list --branch {base} --limit 3
   ```
4. Repeat until all runs on `{base}` are green

**If no runs are found after 60 seconds:** note "no post-merge CI detected" and continue.

Record the final post-merge CI status for the report.

**Clean up the wait subscription:** if you called `subscribe_pr_activity` during the CI gate (step 4), call `unsubscribe_pr_activity` for `{pr_url}` now — the PR is merged, so no more activity needs to wake this session. (Skip this if the user separately asked you to keep watching the PR.)

### 11. Report
```
PR merged ✓
{pr_url}

Reviews: {code review ✓, security review ✓{, architect review ✓} | light review ✓ (small, low-risk diff)}
Findings fixed: {N} code{, M security}{, K architect}{, P suggestions auto-fixed — light-review path}
Merged via: squash merge
Post-merge CI: {pass ✓ | no CI detected | fixed after {N} iteration(s) ✓}

Branch cleaned up. On {base}.

{If the deferred-findings list is non-empty:}
Deferred findings (not blocking, not fixed — consider /draft for any worth tracking):
- [SUGGESTION] {file}:{line} — {description}
- [INFO] {file}:{line} — {description}
- [CONCERN] {area} — {description}
- [ADR NEEDED] {area} — {description}
```
