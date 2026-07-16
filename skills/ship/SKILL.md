---
name: ship
description: "Orchestrate a complete development cycle end-to-end: brainstorm → prioritize → refine → implement → PR → release. Pass explicit ticket IDs to skip brainstorm + prioritize and ship exactly those tickets."
argument-hint: "[TICKET-ID ...] [focus area] [patch|minor|major]"
---

# Ship

Runs a full development cycle by chaining the core workflow skills in sequence — from idea generation through release. One command to ship an entire version.

**Two modes**, chosen by whether you pass ticket IDs:
- **Discovery mode** (no IDs): brainstorm → prioritize → refine → implement → PR → release — the workflow picks what goes in the version.
- **Explicit-ticket mode** (one or more IDs): skips brainstorm and prioritize and ships **exactly** the tickets you name, in the order given → refine → implement → PR → release. Use this when you already know what's in the new version.

## Usage
```
/ship
/ship patch
/ship "focus on performance" minor
/ship "stability improvements"

# Explicit-ticket mode — ship exactly these, skip brainstorm + prioritize:
/ship FEAT-001 FEAT-003
/ship FEAT-001 FEAT-003 minor
/ship BUG-007 patch
```

## Instructions

### 0. Setup

Parse arguments (order-independent):
- **Ticket IDs** — any token matching `{LETTERS}-{NUMBER}` (e.g. `FEAT-001`, `BUG-7`), case-insensitive, normalized to the spec's actual casing. Collect these into `SELECTED_IDS`, **preserving the order given** (that becomes the priority/merge order).
- **Bump type** — `patch`, `minor`, or `major` (default: `minor`).
- **Focus area** — any remaining free text (used only in discovery mode, passed to `/brainstorm` and `/prioritize`).

**Determine the mode:**
- `SELECTED_IDS` is **non-empty** → **explicit-ticket mode**: skip step 1 (brainstorm) and step 2 (prioritize); the selected set IS `SELECTED_IDS`.
- `SELECTED_IDS` is **empty** → **discovery mode**: run steps 1–2 as usual.

**Explicit-ticket mode — validate before doing anything:** for each ID in `SELECTED_IDS`, confirm a spec file exists under `docs/specs/backlog/` or `docs/specs/ready/` (`ls docs/specs/{backlog,ready}/{id}-*.md`). If any ID has no matching spec: **stop** and report which IDs are missing (suggest `/draft` to create them first, or check the ID). Note for each found ID whether it is already in `ready/` (refined — refinement will be skipped for it) or still in `backlog/` (needs refinement).

Read current branch. Must be on the integration branch (`develop` if it exists, otherwise `main`/`master`). If on a feature branch: stop and tell the user to switch to the integration branch first.

Count current backlog (discovery mode only): `ls docs/specs/backlog/ 2>/dev/null | wc -l`

Determine the context file: `git branch --show-current | sed 's|/|-|g'` → `{branch}`. Write the full task list to `.claude/memory/context-{branch}.md` **before any work begins**.

**Discovery mode** checkpoint:
```markdown
## In Progress
task: Full ship cycle — {bump_type} release
skill: ship
mode: discovery
phase: brainstorm
bump: {patch|minor|major}
focus: {focus or "none"}
tasks:
- [ ] Brainstorm new backlog ideas
- [ ] Prioritize and select next-version items
- [ ] Refine: (filled in after prioritize)
- [ ] Implement: (filled in after refine)
- [ ] PR + merge: (filled in after implement)
- [ ] Release {bump_type}
next_step: "Brainstorm"
saved_at: {timestamp}
```

**Explicit-ticket mode** checkpoint (brainstorm + prioritize already resolved; fill the Refine/Implement rows from `SELECTED_IDS` immediately, in the given order — mark any already-refined ticket's Refine row `[x]` up front):
```markdown
## In Progress
task: Full ship cycle — {bump_type} release ({N} explicit tickets)
skill: ship
mode: explicit
phase: refine
bump: {patch|minor|major}
selected: {comma-separated SELECTED_IDS, in order}
tasks:
- [ ] Refine {id-1}          # or [x] if already in ready/
- [ ] Refine {id-2}
- [ ] Implement {id-1}
- [ ] Implement {id-2}
- [ ] PR + merge: (branch names filled in after implement)
- [ ] Release {bump_type}
next_step: "Refine {first id needing refinement, else Implement {id-1}}"
saved_at: {timestamp}
```

### 1. Brainstorm

**Explicit-ticket mode: skip this step entirely** (the tickets are already chosen). Go to step 3.

In supervised mode: ask (AskUserQuestion) "The backlog has {N} items. Run /brainstorm to generate new ideas first, or skip to prioritization?"
- [Run /brainstorm (recommended) / Skip — use existing backlog]

In unsupervised mode: run `/brainstorm` if the backlog has fewer than 3 items; skip if 3 or more.

If running: invoke `/brainstorm` with the focus argument. After completion, new items are in `docs/specs/backlog/`.

Tick off `- [ ] Brainstorm` → `- [x]`. Update checkpoint: `phase: prioritize`, `next_step: "Prioritize"`.

### 2. Prioritize

**Explicit-ticket mode: skip this step entirely** — `SELECTED_IDS` (in the order you passed them) is the selected set and the priority order. Go to step 3.

Invoke `/prioritize` with the focus argument.

After completion, read the selected IDs from `.claude/memory/context-{branch}.md` → `## Next Version Plan` → `selected:` line (e.g., `FEAT-001, FEAT-003`).

If no items were selected: stop. Report "No items selected — add backlog items with /draft and re-run /ship."

Update the task list with the actual IDs (replace the placeholder lines):
```markdown
- [x] Brainstorm new backlog ideas
- [x] Prioritize and select next-version items
- [ ] Refine FEAT-001
- [ ] Refine FEAT-003
- [ ] Implement FEAT-001
- [ ] Implement FEAT-003
- [ ] PR + merge: (branch names filled in after implement)
- [ ] Release {bump_type}
next_step: "Refine FEAT-001"
```

In supervised mode: ask the user to run `/compact` to clear accumulated planning context before starting refinements; wait for confirmation. In unsupervised mode: proceed directly.

### 3. Refine (batched — questions up front, then AFK)

The selected IDs are `SELECTED_IDS` (explicit-ticket mode) or the set read from the prioritize plan (discovery mode). **Refine only the ones still in `docs/specs/backlog/`** — any ID already in `docs/specs/ready/` is refined; skip it (its Refine row is already `[x]`). If every selected ID is already refined, skip straight to step 4.

Invoke `/refine` **once** with all IDs that still need refinement as arguments (e.g. `/refine FEAT-001 FEAT-003`).
This triggers refine's multi-ticket mode: it gathers every clarifying question across all
tickets and asks them in a single batch at the start, then completes every ticket
autonomously — so the user answers once and can walk away for the rest of refinement.

After it returns:
1. Verify each selected spec is in `docs/specs/ready/` (large tickets in supervised mode may be
   held for the batched approval that `/refine` runs at the end — approve as prompted).
2. Tick off each `- [ ] Refine {id}` → `- [x]`; update `next_step`.

If `/refine` reports a blocker on a ticket: in supervised mode, ask how to proceed; in
unsupervised mode, write `## Blocked: /refine {id} failed` and stop.

### 4. Implement + PR (pipelined — CI waits are work time)

`{base}` below = the integration branch from step 0 (`develop` if it exists, else `main`/`master`). Process the tickets in priority order with **one open PR at a time**, overlapping each PR's CI/merge waits with work on the next ticket:

1. **Implement** the next unimplemented ticket: invoke `/implement {id}` (it branches from the integration branch and leaves you on the feature branch).
2. **Open its PR**: merge the base in first (`git fetch origin {base} && git merge origin/{base} --no-edit`; conflicts → supervised: ask, unsupervised: `## Blocked` and stop), then invoke `/pr`.
3. **Fill the waits**: whenever `/pr` arms a CI/merge wait, don't idle — if another ticket is queued, switch to it and continue its work (implementation, or refinement if still missing): tree must be clean (finish/commit the current subtask first), `git checkout {base}`, proceed; its checkpoint and `tier:` line track progress across switches.
4. **PR events always win**: on a CI failure, review round, or merge-ready signal, finish/commit the in-flight subtask, switch back to the PR branch, handle it per `/pr`, then return to the interrupted ticket via its checkpoint (re-arm its tier).
5. When the open PR is **merged + post-merge CI green**: tick off `- [ ] PR + merge: {branch}`, update `next_step`, and open the next ticket's PR as soon as its implementation completes (merge order = priority order; never two open PRs, never code changes on a PR branch except its own CI/review fixes).

In supervised mode: between tickets, ask the user to run `/compact` when the session has accumulated heavy context; in unsupervised mode rely on checkpoints + automatic compaction (keep them current — see the context-hygiene rule in `/implement`).

### 5. Release

Check out the integration branch: `git checkout {develop|main} && git pull`.

Invoke `/release {bump_type}`.

After completion: tick off `- [ ] Release {bump_type}` → `- [x]`. Clear `## In Progress` from the context file.

### 6. Report

```
Ship complete ✓

  Mode:        {discovery | explicit tickets}
  Brainstorm:  {N new ideas added | skipped (explicit tickets)}
  Selected:    {N items}
  Refined:     {ids | "all already refined"}
  Implemented: {ids}
  Merged:      {N PRs}
  Released:    v{new_version}

All CI checks passed. Backlog is ready for the next cycle.
```
