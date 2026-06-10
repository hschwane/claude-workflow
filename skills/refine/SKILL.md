---
name: refine
description: Turn a raw backlog draft into a ready-to-implement spec via iterative Requirements Engineer + Tech Planner loop
argument-hint: "FEAT-001 | BUG-042 | <github-issue-number>"
disable-model-invocation: true
---

# Refine

Turns a raw draft into a ready-to-implement spec through an iterative Requirements Engineer + Tech Planner process. Saves checkpoint for resumability.

## Usage
```
/refine FEAT-001
/refine BUG-042
/refine 42          (GitHub issue number)
```

## Instructions

### 0. Setup
Find the spec:
- By ID: search `docs/specs/backlog/` for matching file
- By GitHub issue: `gh issue view {number}` and find linked spec
- If not found in backlog: check `docs/specs/ready/` — if already ready, tell the user

Read the spec file. Read `docs/VISION.md`. Read root `CLAUDE.md` for architecture context.

Ask the user (AskUserQuestion) before starting:

**Question 1 — Autonomy level:**
- `fully-autonomous`: RE and TP work until DoR is met, only asking when truly stuck
- `key-questions-only`: Ask only the most critical questions (1-3 max)
- `many-questions`: Interview mode — ask about each aspect

**Question 2 — Approval:**
- `auto-accept`: When RE and TP both sign off, automatically move to ready
- `manual-approval`: Show me the final spec and wait for my OK

**Question 3 — Model tier for the planning agents** (requirements-engineer + tech-planner; these are `model: inherit` agents — the choice is passed as the per-invocation `model` parameter, pinned agents like code-explorer are unaffected):
- `session-model` (recommended — name the current session model in the option label): the agents use whatever the session runs on
- `better-than-sonnet`: pass `opus` — for tricky or high-stakes specs when the session runs Sonnet
- `sonnet`: pass `sonnet` — saves budget when the session runs Opus/Fable and the spec is routine
- `haiku`: pass `haiku` — cheapest; only for trivial specs, planning quality will suffer

In unsupervised mode: skip this question, use `session-model`.

Update spec status to `refining`.

### 1. Save Checkpoint
Write to `.claude/memory/context.md`:
```markdown
## In Progress
task: Refining {SPEC_ID} - {title}
phase: refine
spec_file: {spec_path}
autonomy: {level}
approval: {mode}
last_completed: "Started refinement"
next_step: "Phase 1: Requirements Engineer analysis"
saved_at: {timestamp}
```

### 2. Requirements Engineering Phase

Invoke the `requirements-engineer` subagent (isolated context; apply the model tier from Question 3 as the invocation's `model` parameter) with:
```
DRAFT: {full spec file content}
VISION: {docs/VISION.md content}
CONTEXT: {root CLAUDE.md first 80 lines}
```

Read the RE output. Check:
- Does it have `[USER]` open questions? → Ask user via AskUserQuestion (batch multiple questions)
- If user answers provided: note them

Update checkpoint.

### 3. Tech Planning Phase

Invoke the `tech-planner` subagent (isolated context; apply the model tier from Question 3) with:
```
RE_OUTPUT: {requirements engineer's output}
CODEBASE_SUMMARY: {result of reading: tree structure + key src/ files}
ARCHITECTURE: {docs/dev/architecture.md content if exists}
```

For the codebase summary, invoke the `code-explorer` subagent with:
```
QUESTION: Which existing modules, interfaces, and patterns are relevant to implementing this spec? {one-line spec summary}
SCOPE: {affected areas if known}
```
Its briefing (relevant files, key interfaces, patterns, pitfalls) becomes `CODEBASE_SUMMARY`. This keeps the file reading out of both the main context and the tech-planner's context.

Read the TP output. Check:
- Does it have `[TECH]` open questions (for RE)?
- Does it have any questions needing user input?

### 4. Iteration Loop

If the TP output contains RE questions:
- Spawn RE agent again with: `PRIOR_RE_OUTPUT: {...}`, `TP_FEEDBACK: {TP open RE questions}`
- Get updated RE output
- Re-run TP if RE output changed significantly

If `[USER]` questions remain from either agent:
- Collect all questions and ask user in a single AskUserQuestion call
- Pass answers to the next iteration

Continue iterating until:
- No open questions from either agent
- Both RE sign-off and TP sign-off present in their outputs
- OR: maximum 3 iteration rounds reached (then ask user to resolve remaining questions manually)

Update checkpoint after each iteration.

### 5. Assemble Final Spec

Merge the RE output and TP output into the spec file:

```markdown
---
id: {original id}
type: {type}
status: ready
size: {small|medium|large — determined by TP based on subtask count}
created: {original date}
updated: {today}
github_issue: {original value}
---

# {Title}

## User Story
{from RE output}

## Acceptance Criteria
{from RE output}

## Out of Scope
{from RE output}

## Technical Approach
{from TP output}

### Affected Components
{from TP output}

### Interface Definitions
{from TP output — must be complete}

## Subtasks
{from TP output}

## Open Questions
{should be empty}

## Sign-off
- [x] Requirements Engineer
- [x] Tech Planner
```

### 6. Manual Approval (if configured)

If `approval: manual-approval`:
- Show the user the complete final spec
- Ask: "Does this spec look good? [approve / request changes]"
- If changes requested: describe what to change, iterate

### 7. Move to Ready

Move the spec file from `docs/specs/backlog/{file}` to `docs/specs/ready/{file}`.

If GitHub remote exists: update issue labels — remove `backlog`, add `ready`.

Commit:
```
git add docs/specs/
git commit -m "docs(specs): refine {id} — ready to implement"
```

Clear `## In Progress` from `.claude/memory/context.md`.

### 8. Report
```
Spec ready ✓
{id}: {title}
Status: → ready
Subtasks: {N}
Size: {small|medium|large}
Iterations: {N}

Next: /implement {id}   to start implementation
```
