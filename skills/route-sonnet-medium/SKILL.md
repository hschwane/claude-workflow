---
name: route-sonnet-medium
description: Set the working tier to sonnet/medium for the rest of this turn (reverts on next prompt). Invoke per a spec routing block, a workflow skill, or the Adaptive Routing Policy.
model: sonnet
effort: medium
---

# Routing: sonnet / medium

Tier applied for the rest of this turn. Continue immediately with the task in progress — do not summarize, restart, or re-plan.

If a ticket is in progress, keep the checkpoint current: set `tier: sonnet-medium` in the `## In Progress` block of `.claude/memory/context-{branch}.md` (add a short reason if this deviates from the spec's routing block).
