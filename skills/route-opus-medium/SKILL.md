---
name: route-opus-medium
description: Set the working tier to opus/medium for the rest of this turn (reverts on next prompt). Invoke per a spec routing block, a workflow skill, or the Adaptive Routing Policy.
model: opus
effort: medium
---

# Routing: opus / medium

Tier applied for the rest of this turn. Continue immediately with the task in progress — do not summarize, restart, or re-plan.

If a ticket is in progress, keep the checkpoint current: set `tier: opus-medium` in the `## In Progress` block of `.claude/memory/context-{branch}.md` (add a short reason if this deviates from the spec's routing block).
