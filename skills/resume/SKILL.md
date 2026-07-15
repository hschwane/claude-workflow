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

**Re-arm the tier first:** if the checkpoint has a `tier:` line, invoke the matching route skill (e.g. `route-opus-high`) before doing anything else — model/effort routing reverts on every new turn and must be re-applied here. (The tier must be armed before step 4a, because any subagent re-dispatched there needs the correct per-invocation model.)

### 4a. Recover Interrupted Subagents

A session that died mid-phase may have left subagents that never returned. Subagents run synchronously inside the interrupting turn, so a crash before a subagent's result was captured means its work is **lost from context** — it must be recovered before continuing, or the phase proceeds on a missing result.

Build the list of subagents that were in flight when work stopped:
- If the checkpoint has a `subagents:` block, use it — every entry still listed there is one whose result was **not** confirmed captured (skills remove/mark an entry `done` once they consume its result), so each is a crash suspect.
- If there is no `subagents:` block (older checkpoint, or a skill that doesn't record them), **infer from `phase`** which agents that phase runs and check them: `refine` → code-explorer, requirements-engineer, tech-planner · `implement` → test-writer, test-runner, documentation-writer · `pr` → code-reviewer, security-reviewer, architect-reviewer · `project-init` → project-scaffolder · `project-onboard` → code-explorer.

For each in-flight subagent, decide **continue vs. restart** by checking its output — never assume it finished:
- **Read-only agent (reviewers, code-explorer, test-runner, product-owner)** — produces only an in-context report, no file artifact. If the session crashed before the report was consumed, it is gone → **restart** it (same prompt, same tier/model). For a parallel batch (e.g. the three `/pr` reviewers), restart only the entries still listed / not yet reflected in the checkpoint or PR — not the ones whose results already landed.
- **Writer agent (test-writer, documentation-writer, project-scaffolder)** — check its `output` artifact: **missing** → restart; **partial or malformed** → restart (subagents are stateless — re-run from scratch, overwriting the partial file, don't try to hand-patch it); **complete and coherent but its downstream step never ran** → no restart, just **continue** and consume it.

If a subagent had itself launched work that outlived it (a background task, a spawned process): check that task's state before restarting — resume/adopt it if it's still healthy, restart only if it also died. After recovery, mark the recovered entries `done` (or clear them) so a second interruption doesn't re-recover already-finished work.

Announce in one line what was recovered (e.g. "Re-dispatched security-reviewer (report lost in crash); code-reviewer + architect-reviewer results intact"), then continue.

### 4b. Continue the Phase

Continue from the `Next step` in the checkpoint by invoking the appropriate skill behavior:
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
subagents:
  - agent: test-writer
    for: "Subtask #3 tests"
    output: tests/auth/github.test.ts   # artifact to verify; omit for read-only agents (reviewers, explorers)
    status: dispatched                   # dispatched = in flight / result not yet captured · done = result consumed
saved_at: 2026-06-10T14:32:00Z
```

**`subagents:` block (optional).** Records subagents currently in flight so `/resume` step 4a can tell a crashed one from a finished one. A skill adds an entry (`status: dispatched`) **immediately before spawning** the subagent, and flips it to `done` (or removes it) **once it has captured/consumed the result**. Any entry still `dispatched` at resume time is a crash suspect. Omit the block entirely when no subagent is in flight; omit `output` for read-only agents that produce only an in-context report. For a parallel batch, list one entry per agent so recovery can restart just the ones that didn't finish.
