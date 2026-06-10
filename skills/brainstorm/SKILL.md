---
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

### 1. Spawn Analysis Agent
Spawn a subagent (context:fork) with the following task:

> Read and summarize the project's current state. Input available:
> - `docs/VISION.md` — product goals, target audience, non-goals
> - `docs/specs/completed/` — what has been implemented (list titles + 1-line summaries)
> - `docs/specs/ready/` and `docs/specs/backlog/` — what's planned (list titles)
> - `CHANGELOG.md` — recent releases and changes
> - Top-level file structure (`ls -la` or `Get-ChildItem`)
> 
> Produce a concise project summary (max 300 words) covering:
> 1. What exists today (key features, recent additions)
> 2. Observable gaps or incomplete areas
> 3. Recurring themes in the backlog
> 4. Anything the vision mentions that hasn't been started yet
> 
> Then suggest 8-12 specific feature or improvement ideas grouped by theme. For each idea, write one sentence describing it and one sentence on why it's valuable given the project's goals.

### 2. Present Summary
Show the user the project summary from the analysis agent. If the user provided a focus area (e.g., "performance"), note it and ask the agent to weight suggestions accordingly.

### 3. Interactive Ideation Loop
Present ideas to the user in small batches (3-4 at a time). For each batch:

Use AskUserQuestion to let the user react:
- Accept idea as-is → immediately call `/draft feature "{idea title}"` behavior (see draft skill)
- Accept with modification → ask for the modified title/description, then draft it
- Skip → note it and move to next batch
- Add own idea → user types it, draft it immediately, continue
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
Append a note to `.claude/memory/context.md`:
```markdown
## Last Brainstorm
date: {YYYY-MM-DD}
added: {N} items
focus: {focus area if specified, otherwise "general"}
```
