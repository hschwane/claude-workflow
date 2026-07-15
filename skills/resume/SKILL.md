---
name: resume
description: Resume interrupted in-progress work from the branch-scoped checkpoint in .claude/memory/. Use when a session starts with an AUTO-RESUME directive, or when the user asks to continue interrupted work.
---

# Resume

Resumes in-progress work that was interrupted by a token limit, session end, or manual stop. Reads the branch-scoped checkpoint and continues from where work left off.

## Usage
```
/resume
```

## Instructions

### 0. Check Current Session Context First
Before reading the checkpoint file, scan the current conversation for a compaction summary. Claude Code inserts a `Summary:` block at the top of the context window when prior messages were compressed — this is often more up-to-date than the last checkpoint write.

If the summary mentions in-progress work (e.g., "was implementing subtask #3 of FEAT-001 when the session ended"), extract `last_completed` and `next_step` from it. Then read the checkpoint file (step 1) and reconcile: **if they conflict, the conversation summary wins** — it reflects what actually happened last, including any work done after the checkpoint was written.

If there is no compaction summary in the current context, proceed directly to step 1.

### 1. Read Current Context
Determine the context file:
1. Run `git branch --show-current | sed 's|/|-|g'` to get `{branch}`
2. Read `.claude/memory/context-{branch}.md` if it exists
3. Otherwise fall back to `.claude/memory/context.md` (legacy)

Look for a section titled `## In Progress`.

If no `## In Progress` section exists in either file:
- Print: "No in-progress work found"
- List any specs with status `in-progress` from `docs/specs/`
- If specs with `in-progress` status exist: ask user which one to resume

### 2. Display the In-Progress State
Show the user what was in progress:
```
Resuming: {task description}
Phase: {phase}
Branch: {branch}
Last completed: {last step}
Next step: {what to do next}
```

Ask the user: "Should I continue from here?" (unless there is only one obvious next step, in which case proceed immediately).

### 3. Restore Context
Before continuing, read the relevant files:
- The spec file for the in-progress task — **its unchecked subtask boxes are the source of truth for remaining work** (the checkpoint only stores the pointer)
- Current git branch: `git branch --show-current`
- Recent commits on the branch (`git log --oneline -5`) — they confirm which subtasks really completed

Verify the git state matches the checkpoint (correct branch, expected files). If the spec's checkboxes and the git log disagree, trust the git log and fix the checkboxes.

### 4. Continue Work

**Re-arm the tier first:** if the checkpoint has a `tier:` line, invoke the matching route skill (e.g. `route-opus-high`) before doing anything else — model/effort routing reverts on every new turn and must be re-applied here.

Then continue from the `Next step` in the checkpoint by invoking the appropriate skill behavior:
- If `phase: implement` and `next_step` is a subtask → continue implementing that subtask
- If `phase: refine` → continue the refinement loop
- If `phase: pr` → check if CI is running, pick up from there
- If `phase: release` → pick up from the release step

### 5. After Resuming
Clear the `## In Progress` section from the context file once the work is truly complete (merged PR or confirmed done by user).

## Checkpoint Format
(Written by other skills when they save progress. File: `.claude/memory/context-{branch}.md` where `{branch}` = current branch with `/` → `-`. Deliberately minimal: remaining subtasks are NOT duplicated here — they live as checkboxes in the spec file.)

```markdown
## In Progress
task: FEAT-001 - OAuth Login
phase: implement
branch: feature/feat-001-oauth-login
spec_file: docs/specs/ready/FEAT-001-oauth-login.md
tier: sonnet-medium
last_completed: "Subtask #2: Implement GoogleOAuthProvider — committed abc1234"
next_step: "Implement Subtask #3: GitHubOAuthProvider in src/auth/providers/github.ts"
saved_at: 2026-06-10T14:32:00Z
```
