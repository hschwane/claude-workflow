---
name: refine
description: Turn a raw backlog draft into a ready-to-implement spec via iterative Requirements Engineer + Tech Planner loop
argument-hint: "FEAT-001 | BUG-042 | <github-issue-number>"
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

### 0. Branch Check
Run `git branch --show-current`. If the result is not `develop`, `main`, or `master`, warn the user:

> ⚠ You are on branch `{branch}`. Refinement is a planning activity and should normally run on your integration branch (`develop` or `main`) so spec changes don't accumulate on feature branches. Continue here, or switch branches first?

Ask (AskUserQuestion): [Continue on this branch / I'll switch first — stopping now]

If the user wants to switch: stop. Do not proceed until they re-run `/refine` from the right branch.

### 0.1 Setup
Find the spec:
- By ID: search `docs/specs/backlog/` for matching file
- By GitHub issue: `gh issue view {number}` and find linked spec
- If not found in backlog: check `docs/specs/ready/` — if already ready, tell the user

Read the spec file. Read `docs/VISION.md`. Read root `CLAUDE.md` for architecture context.

### 0.2 Complexity Triage

Assess the draft's complexity. This is a judgment call — there are **no hard limits** (subtask counts etc.); weigh scope, novelty, risk, and ambiguity together:

- **small** — isolated change in known territory: few components affected, no new public interfaces (or only trivial extensions of existing ones), no security relevance, scope is unambiguous
- **medium** — moderate scope: new interfaces or several components affected, some ambiguity to resolve
- **large** — new architecture or patterns, security-relevant, cross-cutting, breaking changes, or significant ambiguity

**When uncertain between two tiers, pick the higher one.** The tier scales the whole process: how many agents run, how many iteration rounds are allowed, and how many clarifying questions the user gets.

Show your assessment and ask (AskUserQuestion):
> "I assess {id} as **{tier}** — {one-line reason}. Proceed?"
- For small: [Fast-track it / Treat as medium / Treat as large]
- For medium/large: [Proceed with defaults / Customize / Change tier]

Defaults are: `fully-autonomous`, `auto-accept`, `session-model`. If the user picks **Customize**, ask the detailed questions:

**Autonomy level:** `fully-autonomous` (agents work until DoR is met, only asking when truly stuck) / `key-questions-only` (1-3 critical questions max) / `many-questions` (interview mode)

**Approval:** `auto-accept` (move to ready when both agents sign off) / `manual-approval` (show final spec, wait for OK)

**Model tier for the planning agents** (requirements-engineer + tech-planner are `model: inherit` — pass the choice as the per-invocation `model` parameter; pinned agents like code-explorer are unaffected): `session-model` (recommended) / `opus` (tricky or high-stakes specs when the session runs Sonnet) / `sonnet` (saves budget when the session runs Opus/Fable) / `haiku` (only for trivial specs, planning quality will suffer)

In unsupervised mode: skip all questions, trust the triage (bias toward the higher tier when uncertain), use the defaults.

Update spec status to `refining`.

### 1. Save Checkpoint
Determine the context file path: run `git branch --show-current | sed 's|/|-|g'` to get `{branch}`, then write to `.claude/memory/context-{branch}.md`:
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

### 1b. Fast-Track Path (small specs only)

For **small** specs, skip steps 2–4 entirely:

1. **Codebase context**: if the affected files are already obvious from the current session, assemble a short summary yourself; otherwise invoke `code-explorer` as described in step 3.
2. Invoke the `tech-planner` subagent ONCE in fast-track mode with:
   ```
   DRAFT: {full spec file content}
   VISION: {docs/VISION.md content}
   CODEBASE_SUMMARY: {briefing}
   ARCHITECTURE: {docs/dev/architecture.md content if exists}
   ```
   No `RE_OUTPUT` — in fast-track mode the tech-planner derives the user story and acceptance criteria itself before planning.
3. **If its output starts with `ESCALATE:`** — the spec is more complex than assessed. Inform the user, re-tier to medium (or large if the reason warrants), and run the normal steps 2–4; the partial output is useful context for the RE.
4. Otherwise: continue at step 5, using the combined output for both the RE sections and the TP sections.

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

If `[USER]` questions remain from either agent — scale to the tier:
- **medium**: ask only questions that genuinely block the plan (max 3, single AskUserQuestion call); answer the rest with reasonable assumptions and record each assumption in the spec under a `## Assumptions` note
- **large**: collect all questions and ask in a single AskUserQuestion call
- Pass answers to the next iteration

Continue iterating until:
- No open questions from either agent
- Both RE sign-off and TP sign-off present in their outputs
- OR: maximum iteration rounds reached — **1 round for medium, 3 for large** (then ask the user to resolve remaining questions manually)

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

```bash
git mv docs/specs/backlog/{filename} docs/specs/ready/{filename}
```

If `.claude/memory/decisions.md` does NOT contain `GitHub integration: no`: update issue labels — remove `backlog`, add `ready` (`gh issue edit {github_issue} --remove-label backlog --add-label ready`).

Commit:
```bash
git add docs/specs/
git commit -m "docs(specs): refine {id} — ready to implement"
```

Clear `## In Progress` from the branch context file.

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
