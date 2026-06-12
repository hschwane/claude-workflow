---
name: brainstorm
description: Analyze the project state and generate backlog ideas in an interactive session — accepted ideas become drafts
argument-hint: "[optional focus area]"
disable-model-invocation: true
---

# Brainstorm

Analyzes the current project state and helps generate new backlog ideas through an interactive conversation. Each accepted idea is automatically added as a draft.

## Usage
```
/brainstorm
/brainstorm "focus on performance improvements"
/brainstorm "what's missing compared to our vision?"
```

## Instructions

### 0. Branch Check
Run `git branch --show-current`. If the result is not `develop`, `main`, or `master`, warn the user:

> ⚠ You are on branch `{branch}`. Brainstorming is a planning activity and should normally run on your integration branch (`develop` or `main`) so spec changes don't end up on feature branches. Continue here, or switch branches first?

Ask (AskUserQuestion): [Continue on this branch / I'll switch first — stopping now]

If the user wants to switch: stop.

### 1. Invoke Product Owner Agent
Invoke the `product-owner` subagent with:
```
MODE: ideate
VISION: docs/VISION.md
STATE: docs/specs/completed/ titles, CHANGELOG.md, top-level file structure
BACKLOG: docs/specs/ready/ and docs/specs/backlog/ titles
FOCUS: {user's focus argument, if any}
```

It returns a project summary (max 300 words) plus 8-12 ideas grouped by theme, each with a vision-relevance score.

### 2. Present Summary
Show the user the project summary from the analysis agent. If the user provided a focus area (e.g., "performance"), note it and ask the agent to weight suggestions accordingly.

### 3. Interactive Ideation Loop
Present ideas to the user in small batches (3-4 at a time). For each batch:

Use AskUserQuestion to let the user react:
- Accept idea as-is → immediately call `/draft feature "{idea title}"` behavior (see draft skill)
- Accept with modification → ask for the modified title/description, then draft it
- Skip → note it and move to next batch
- Add own idea → run it through the `product-owner` subagent (`MODE: evaluate`) for a quick vision-fit check, show the verdict, then draft it if the user still wants it
- Stop → end the session

Continue until the user stops or all ideas are reviewed.

### 4. Session Summary
At the end, print:
```
Brainstorming complete.
Added {N} items to backlog:
  - FEAT-007: {title}
  - FEAT-008: {title}
  ...

Next: /refine FEAT-007   to start refining the first new item
```

### 5. Update Memory
Append a note to the branch context file (`.claude/memory/context-{branch}.md`):
```markdown
## Last Brainstorm
date: {YYYY-MM-DD}
added: {N} items
focus: {focus area if specified, otherwise "general"}
```
