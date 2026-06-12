---
name: prioritize
description: Rank the backlog against the product vision and select the items for the next version, ready to be refined
argument-hint: "[optional: focus area or number of items]"
disable-model-invocation: true
---

# Prioritize

Ranks all backlog items against the product vision (via the product-owner agent) and helps select which items to refine for the next version.

## Usage
```
/prioritize
/prioritize "focus on stability"
/prioritize 4          (select ~4 items)
```

## Instructions

### 0. Branch Check
Run `git branch --show-current`. If the result is not `develop`, `main`, or `master`, warn the user:

> ⚠ You are on branch `{branch}`. Prioritization is a planning activity and should normally run on your integration branch (`develop` or `main`). Continue here, or switch branches first?

Ask (AskUserQuestion): [Continue on this branch / I'll switch first — stopping now]

If the user wants to switch: stop.

### 1. Collect Backlog State
- List all specs in `docs/specs/backlog/` (id, title, size if present)
- List `docs/specs/ready/` (already refined — mention but exclude from ranking)
- If the backlog is empty: suggest `/brainstorm` or `/draft` and stop.

### 2. Invoke Product Owner
Invoke the `product-owner` subagent with:
```
MODE: prioritize
VISION: docs/VISION.md
STATE: docs/specs/completed/ titles + CHANGELOG.md
BACKLOG: {list of backlog items with their spec file contents (frontmatter + user story only)}
FOCUS: {user's focus argument, if any}
```

### 3. Present Recommendation
Show the user:
- The ranked list (score, one-line rationale each)
- The recommended next-version slate
- Any decline/archive suggestions

Ask (AskUserQuestion, multiSelect): "Which items should move forward for refinement?" — options from the recommended slate, plus "follow the full recommendation".

In unsupervised mode: accept the agent's recommended slate as-is.

### 4. Record the Selection
Append to the branch context file (`.claude/memory/context-{branch}.md`):
```markdown
## Next Version Plan
selected: {ids in refinement order}
declined: {ids, if user confirmed archiving}
decided: {YYYY-MM-DD}
```

For confirmed decline/archive items: move the spec to `docs/specs/completed/` with frontmatter `status: declined` (after explicit user confirmation only — never in unsupervised mode).

If GitHub remote exists: no label changes needed yet (labels change during /refine).

### 5. Report
```
Next version plan ✓
Selected for refinement (in order):
  1. FEAT-007: {title}   → /refine FEAT-007
  2. FEAT-003: {title}
  ...
{Declined: BUG-002 (no longer fits vision)}

Next: /refine {first id}
```
