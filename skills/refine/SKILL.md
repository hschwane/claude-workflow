---
name: refine
description: Turn a raw backlog draft into a ready-to-implement spec via iterative Requirements Engineer + Tech Planner loop. Accepts multiple IDs — batches all questions up front so you can go AFK.
argument-hint: "FEAT-001 | BUG-042 | <github-issue-number> | FEAT-001 FEAT-003 …"
---

# Refine

Turns a raw draft into a ready-to-implement spec through an iterative Requirements Engineer + Tech Planner process. Saves checkpoint for resumability.

## Usage
```
/refine FEAT-001
/refine BUG-042
/refine 42                     (GitHub issue number)
/refine FEAT-001 FEAT-003 BUG-007   (multiple — questions batched up front, then AFK)
```

## Multi-Ticket Mode (2+ IDs)

When more than one ID is given, refine them as a batch with a **single interactive
touchpoint at the start**: collect every clarifying question across all tickets, ask them
once, then complete every ticket autonomously so the user can walk away.

Run the branch check (step 0) once, then:

**Phase A — Gather questions (all tickets, no user interaction).** For each ticket in order,
run setup + triage (steps 0.1–0.2) and the analysis that surfaces user questions — the RE
phase (step 2), plus a Tech-Planner pass (step 3) for medium/large tickets. **Defer every
`AskUserQuestion`:** instead of asking, collect each `[USER]` question, tagged with its
ticket ID, and save the intermediate agent outputs in that ticket's checkpoint. trivial and
small tickets (no questions) need nothing here. Respect each ticket's size-based question budget
from §0.2 when deciding which questions are worth surfacing.

**Phase B — Ask once.** Present all collected questions across all tickets in a single
`AskUserQuestion` flow, grouped by ticket (one question per distinct decision; batch related
ones). This is the only interactive step — tell the user they can go AFK after answering.
If **no** questions were collected (e.g. all small/medium with no blockers), skip straight to
Phase C without prompting.

**Phase C — Complete (all tickets, autonomous).** For each ticket, resume from its checkpoint
with the user's answers and finish the remaining steps — trivial tickets run the fast-track path
(step 1b) then steps 5–5b; small tickets run steps 2–5b; medium/large tickets finish steps 3–5b
(TP iteration, assemble spec, draft out-of-scope follow-ups). Then:
- **auto-accept** tickets (trivial/small/medium) → move to `ready` immediately (step 7).
- **manual-approval** tickets (large) → refine fully but **hold in backlog**, queued for the
  end-of-run review.
- If a **new** `[USER]` question surfaces here that Phase B didn't cover, do **not** block —
  resolve it with a reasonable assumption and record it under `## Assumptions` in the spec
  (the user is AFK). Only a genuine hard blocker (per the unsupervised blocker list) stops that
  one ticket; continue the others.

**Phase D — Report + batched approval.** When all tickets are done:
- If any **manual-approval** tickets are held: present them together (step 6) so the user
  approves/adjusts them in one pass when they return.
- Report every ticket as in step 8 (a one-line status per ID).

**Checkpoint (resumability).** Write the batch state to `.claude/memory/context-{branch}.md`:
the full list of IDs, the current phase (`gathering` / `awaiting-answers` / `completing`), and
per-ticket status (`pending` / `questions-collected` / `answered` / `ready` / `held-for-approval`
/ `blocked`) plus each ticket's collected questions, answers, and refinement tier (elevate/step
down per ticket — a large ticket's `route-best-high` never spans other tickets). Update it after each ticket in
Phase A, after Phase B (record answers), and after each ticket completes in Phase C — so a crash
resumes at the right phase without re-asking answered questions.

For a **single** ID, ignore this section and follow the numbered steps below as normal
(questions are asked as they arise, scaled to the ticket's size).

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

- **trivial** — mechanical or cosmetic change, fully unambiguous, no interface or security impact (typo-level fixes, config tweaks, copy changes)
- **small** — isolated change in known territory: few components affected, no new public interfaces (or only trivial extensions of existing ones), no security relevance, scope is unambiguous
- **medium** — moderate scope: new interfaces or several components affected, some ambiguity to resolve
- **large** — new architecture or patterns, security-relevant, cross-cutting, breaking changes, or significant ambiguity

**When uncertain between two tiers, pick the higher one.** The tier scales the whole process: how many agents run, how many iteration rounds are allowed, and how many clarifying questions the user gets.

The tier also fixes the process settings and the **refinement tier** (model+effort for planning agents and, per project policy, the review of this ticket) via this table. **Apply them automatically; do not ask.**

| Tier | Autonomy | Approval | Rounds | Refinement tier |
|------|----------|----------|--------|-----------------|
| **trivial** | `fully-autonomous` — no questions | `auto-accept` | fast-track (1 TP pass) | `sonnet-high` |
| **small** | `fully-autonomous` — no questions | `auto-accept` | 1 | `opus-high` |
| **medium** | `key-questions-only` — 1–3 critical questions max | `auto-accept` | 1 | `opus-high` |
| **large** | `many-questions` — interview mode | `manual-approval` | 3 | `best-high` |

The refinement tier's **model** is passed as the per-invocation `model` parameter to the `requirements-engineer` + `tech-planner` subagents (trivial → `sonnet`, small/medium → `opus`, large → `fable`; if fable is unavailable it falls back automatically). Their **effort** is pinned `high` in their frontmatter. Pinned agents like `code-explorer` are unaffected.

**large only:** additionally invoke the `route-best-high` skill now, so the orchestrating judgment of this refine run (iteration decisions, spec assembly) also runs top-tier. **Step down again** (invoke `route-sonnet-medium`) as soon as this ticket's spec is assembled (after step 5b) — the elevation must not leak into other tickets in a multi-ticket batch, a `/ship` run, or a `/pr` CI wait.

State your assessment in one line so the user sees it, then **proceed without asking** — e.g. *"Assessed {id} as **medium** — new interface on the existing parser. Refining with key-questions / auto-accept / opus-high."* Do not ask the user to confirm the tier or the settings. Offer a tier change **only** if the user has explicitly asked to be consulted on sizing; in that case ask via AskUserQuestion: [Proceed as {tier} / Treat as {lower tier} / Treat as {higher tier}].

In unsupervised mode: state the assessment, ask **no** questions at all (even at the large tier, where `many-questions` collapses to fully-autonomous), and self-approve the finished spec (`auto-accept` regardless of tier).

Update spec status to `refining`.

### 0.3 Bug Evidence (type: bug only)

Before planning a bug fix, try to ground it in real evidence — autonomously:

1. **Application logs**: if the project is deployed (see `docs/workflow/deploy.md`), pull recent logs from the platform — e.g. via the Railway MCP tools (`get_logs` for the affected service/deployment) or the platform CLI. Filter around the reported symptom/timeframe.
2. **Local evidence**: failing test output, stack traces in the report, `git log` of recently changed files in the affected area.

Condense findings to a short `EVIDENCE:` block (≤15 lines: relevant log excerpts, error signatures, suspicious commits) and pass it to the RE/TP inputs below. If no logs are accessible, note that and continue — don't block on it.

### 1. Save Checkpoint
Determine the context file path: run `git branch --show-current | sed 's|/|-|g'` to get `{branch}`, then write to `.claude/memory/context-{branch}.md`:
```markdown
## In Progress
task: Refining {SPEC_ID} - {title}
phase: refine
spec_file: {spec_path}
autonomy: {level}
approval: {mode}
tier: {refinement tier from §0.2 — /resume re-arms it (relevant for large tickets)}
last_completed: "Started refinement"
next_step: "Phase 1: Requirements Engineer analysis"
saved_at: {timestamp}
```

### 1b. Fast-Track Path (trivial specs only)

For **trivial** specs, skip steps 2–4 entirely:

1. **Codebase context**: if the affected files are already obvious from the current session, assemble a short summary yourself; otherwise invoke `code-explorer` as described in step 3.
2. Invoke the `tech-planner` subagent ONCE in fast-track mode (apply `model: sonnet` per the §0.2 tier table) with:
   ```
   DRAFT: {full spec file content}
   VISION: {docs/VISION.md content}
   CODEBASE_SUMMARY: {briefing}
   ARCHITECTURE: {docs/dev/architecture.md content if exists}
   ```
   No `RE_OUTPUT` — in fast-track mode the tech-planner derives the user story and acceptance criteria itself before planning.
3. **If its output starts with `ESCALATE:`** — the spec is more complex than assessed. Inform the user, re-tier to small/medium (or large if the reason warrants), and run the normal steps 2–4; the partial output is useful context for the RE.
4. Otherwise: continue at step 5, using the combined output for both the RE sections and the TP sections.

**Crash safety for the RE/TP phases (steps 2–4).** The RE and tech-planner outputs are held in context and not written to the spec file until step 5, so an interruption before the merge loses them. Two rules: (1) before invoking each agent, add a `subagents:` entry to the checkpoint (`agent: requirements-engineer`/`tech-planner`, `status: dispatched`, no `output` — they write no file yet); (2) once an agent's output is in hand, save it into the checkpoint (`RE_OUTPUT:` / `TP_OUTPUT:` block, as multi-ticket Phase A already does) and mark its entry `done`. On `/resume`, step 4a re-dispatches only the agent still `dispatched`; an agent whose output is already stored is not re-run. Clear the stored outputs when step 5 has merged them into the spec.

### 2. Requirements Engineering Phase

Invoke the `requirements-engineer` subagent (isolated context; apply the refinement-tier model from the §0.2 table as the invocation's `model` parameter) with:
```
DRAFT: {full spec file content}
VISION: {docs/VISION.md content}
CONTEXT: {root CLAUDE.md first 80 lines}
EVIDENCE: {bug evidence block from §0.3, if any}
```

Read the RE output. Check:
- Does it have `[USER]` open questions? → Ask user via AskUserQuestion (batch multiple questions). **In multi-ticket Phase A: do not ask — collect these tagged with the ticket ID and continue (see Multi-Ticket Mode).**
- If user answers provided: note them

Update checkpoint.

### 3. Tech Planning Phase

Invoke the `tech-planner` subagent (isolated context; apply the refinement-tier model from the §0.2 table) with:
```
RE_OUTPUT: {requirements engineer's output}
CODEBASE_SUMMARY: {result of reading: tree structure + key src/ files}
ARCHITECTURE: {docs/dev/architecture.md content if exists}
EVIDENCE: {bug evidence block from §0.3, if any}
```

For the codebase summary, invoke the `code-explorer` subagent with:
```
QUESTION: Which existing modules, interfaces, and patterns are relevant to implementing this spec? {one-line spec summary}
SCOPE: {affected areas if known}
```
Its briefing (relevant files, key interfaces, patterns, pitfalls) becomes `CODEBASE_SUMMARY`. This keeps the file reading out of both the main context and the tech-planner's context.

Read the TP output. Check:
- Does its "Open Questions for RE" section contain anything?
- Does it have any `[USER]` questions needing user input?

### 4. Iteration Loop

If the TP output contains RE questions:
- Spawn RE agent again with: `PRIOR_RE_OUTPUT: {...}`, `TP_FEEDBACK: {TP open RE questions}`
- Get updated RE output
- Re-run TP if RE output changed significantly

If `[USER]` questions remain from either agent — scale to the tier:
- **medium**: ask only questions that genuinely block the plan (max 3, single AskUserQuestion call); answer the rest with reasonable assumptions and record each assumption in the spec under a `## Assumptions` note
- **large**: collect all questions and ask in a single AskUserQuestion call
- Pass answers to the next iteration
- **Multi-ticket mode:** in Phase A, collect these (tagged with the ticket ID) instead of asking; in Phase C the user is AFK, so resolve any newly-surfaced question with a recorded `## Assumptions` note rather than asking.

Continue iterating until:
- No open questions from either agent
- Both RE sign-off and TP sign-off present in their outputs
- OR: maximum iteration rounds reached — **1 round for small/medium, 3 for large** (then ask the user to resolve remaining questions manually)

Update checkpoint after each iteration.

### 5. Assemble Final Spec

Merge the RE output and TP output into the spec file:

```markdown
---
id: {original id}
type: {type}
status: ready
size: {trivial|small|medium|large — the §0.2 triage tier, re-tiered if the fast-track escalated}
routing:
  refinement: {tier from the §0.2 table, e.g. opus-high}
  implementation: {from the TP output's Routing Recommendation; default sonnet-medium.
                   Allowed: sonnet-medium | sonnet-high | opus-medium | opus-high | best-medium (hardest only).
                   Never best-high or haiku.}
  test_writing: {model only, from TP: sonnet (default) | opus; never above the implementation model}
version: {original value — preserve the milestone assigned by /draft or /project-init}
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

### 5b. Draft Out-of-Scope Follow-ups

Review the "Out of Scope" section assembled in step 5. Also check the RE and TP outputs for any items flagged as out-of-scope during the iteration.

**Rule: if any item is described with wording like "another ticket", "separate ticket", "future ticket", "follow-up ticket", or "own ticket", create a draft — no judgment call, always.**

For other out-of-scope items without that explicit label, classify:
- **Deferred work** — something that could be a future feature or enhancement (e.g., "admin UI for managing X", "export to PDF"): create a draft ticket
- **Permanent constraint** — an architectural or project-level decision that will never change (e.g., "no i18n", "browser-only, no native app"): skip — this belongs in `docs/VISION.md`, not the backlog

For each item that requires a draft, create a file in `docs/specs/backlog/`:

1. Determine the next available ID across all spec directories:
   ```bash
   ls docs/specs/backlog/ docs/specs/ready/ docs/specs/completed/ 2>/dev/null \
     | grep -oP '(FEAT|BUG)-[0-9]+' | sort -t- -k2 -n | tail -1
   ```
   Increment the number (e.g., `FEAT-007` → `FEAT-008`). If none exist, start at `FEAT-001`.

2. Write `docs/specs/backlog/{ID}-{kebab-title}.md` with frontmatter:
   `id: {ID}`, `type: feature`, `status: draft`, `created: {today}`, and a body that includes:
   - A short title
   - A `## Background` section noting it was deferred from `{original-spec-id}` and why

3. If any drafts were created:
   ```bash
   git add docs/specs/backlog/
   git commit -m "docs(specs): draft follow-ups from {id} out-of-scope items"
   ```

List the created draft IDs in the final report (step 8).

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
Size: {trivial|small|medium|large}
Routing: impl {tier} · tests {model}
Iterations: {N}

Next: /implement {id}   to start implementation
```
