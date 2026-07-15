---
name: route-sonnet-high
description: Set the working tier to sonnet/high for the rest of the current turn. Invoke when a spec routing block, a workflow skill, or the Adaptive Routing Policy (project CLAUDE.md) directs it. Applies model and effort together; reverts automatically on the next user prompt.
model: sonnet
effort: high
---

# Routing: sonnet / high

Tier applied for the rest of this turn. Continue immediately with the task in progress — do not summarize, restart, or re-plan.

If a ticket is in progress, keep the checkpoint current: set `tier: sonnet-high` in the `## In Progress` block of `.claude/memory/context-{branch}.md` (add a short reason if this deviates from the spec's routing block).
