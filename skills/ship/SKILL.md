---
name: ship
description: Orchestrate a complete development cycle end-to-end: brainstorm → prioritize → refine → implement → PR → release
argument-hint: "[focus area] [patch|minor|major]"
---

# Ship

Runs a full development cycle by chaining the core workflow skills in sequence — from idea generation through release. One command to ship an entire version.

## Usage
```
/ship
/ship patch
/ship "focus on performance" minor
/ship "stability improvements"
```

## Instructions

### 0. Setup

Parse arguments:
- Extract bump type if present: `patch`, `minor`, or `major` (default: `minor`)
- Remaining text: use as the focus area passed to `/brainstorm` and `/prioritize`

Read current branch. Must be on the integration branch (`develop` if it exists, otherwise `main`/`master`). If on a feature branch: stop and tell the user to switch to the integration branch first.

Count current backlog: `ls docs/specs/backlog/ 2>/dev/null | wc -l`

Determine the context file: `git branch --show-current | sed 's|/|-|g'` → `{branch}`. Write the full task list to `.claude/memory/context-{branch}.md` **before any work begins**:

```markdown
## In Progress
task: Full ship cycle — {bump_type} release
skill: ship
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

### 1. Brainstorm

In supervised mode: ask (AskUserQuestion) "The backlog has {N} items. Run /brainstorm to generate new ideas first, or skip to prioritization?"
- [Run /brainstorm (recommended) / Skip — use existing backlog]

In unsupervised mode: run `/brainstorm` if the backlog has fewer than 3 items; skip if 3 or more.

If running: invoke `/brainstorm` with the focus argument. After completion, new items are in `docs/specs/backlog/`.

Tick off `- [ ] Brainstorm` → `- [x]`. Update checkpoint: `phase: prioritize`, `next_step: "Prioritize"`.

### 2. Prioritize

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

Invoke `/refine` **once** with all selected IDs as arguments (e.g. `/refine FEAT-001 FEAT-003`).
This triggers refine's multi-ticket mode: it gathers every clarifying question across all
tickets and asks them in a single batch at the start, then completes every ticket
autonomously — so the user answers once and can walk away for the rest of refinement.

After it returns:
1. Verify each selected spec is in `docs/specs/ready/` (large tickets in supervised mode may be
   held for the batched approval that `/refine` runs at the end — approve as prompted).
2. Tick off each `- [ ] Refine {id}` → `- [x]`; update `next_step`.

If `/refine` reports a blocker on a ticket: in supervised mode, ask how to proceed; in
unsupervised mode, write `## Blocked: /refine {id} failed` and stop.

### 4. Implement (each item, sequential)

For each refined item in order:
1. Invoke `/implement {id}`
2. After completion, capture the feature branch name: `git branch --show-current`
3. Tick off `- [ ] Implement {id}` → `- [x]`
4. Update the `PR + merge` entries in the task list with the actual branch name
5. Update `next_step`

Note: `/implement` leaves you on the feature branch. The next `/implement` automatically returns to the integration branch and creates a new branch — no manual switching needed.

In supervised mode: after all implementations are done, ask the user to run `/compact` before the PR phase; wait for confirmation. In unsupervised mode: proceed directly.

### 5. PR + Merge (each feature branch, sequential)

For each feature branch in implementation order:
1. Check out the branch: `git checkout {feature_branch}`
2. Merge the base branch into the feature branch to incorporate any earlier merges:
   ```bash
   git fetch origin {base}
   git merge origin/{base} --no-edit
   ```
   If merge conflicts: in supervised mode, ask the user to resolve them; in unsupervised mode, write `## Blocked: merge conflict on {feature_branch}` and stop.
3. Invoke `/pr` (targets the integration branch)
4. After the PR is merged and post-merge CI passes, tick off `- [ ] PR + merge: {branch}` → `- [x]`
5. Update `next_step`

### 6. Release

Check out the integration branch: `git checkout {develop|main} && git pull`.

Invoke `/release {bump_type}`.

After completion: tick off `- [ ] Release {bump_type}` → `- [x]`. Clear `## In Progress` from the context file.

### 7. Report

```
Ship complete ✓

  Brainstorm:  {N new ideas added | skipped}
  Selected:    {N items}
  Refined:     {ids}
  Implemented: {ids}
  Merged:      {N PRs}
  Released:    v{new_version}

All CI checks passed. Backlog is ready for the next cycle.
```
