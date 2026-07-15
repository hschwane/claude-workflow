---
name: route-best-medium
description: Set the working tier to the top-tier model at medium effort for the rest of the current turn — for the hardest implementation work and advisor-grade judgment. Invoke when a spec routing block, a workflow skill, or the Adaptive Routing Policy (project CLAUDE.md) directs it. Reverts automatically on the next user prompt.
model: best
effort: medium
---

# Routing: top-tier / medium

<!-- top-tier mapping: fable (current). Tunable via /workflow-decisions "Top-tier mapping":
     fable            → model: best, effort: medium  (best = Fable if available, else latest Opus)
     opus-compensated → model: opus, effort: high    (use when Fable access has ended, to compensate with effort) -->

Tier applied for the rest of this turn. Continue immediately with the task in progress — do not summarize, restart, or re-plan.

If a ticket is in progress, keep the checkpoint current: set `tier: best-medium` in the `## In Progress` block of `.claude/memory/context-{branch}.md` (add a short reason if this deviates from the spec's routing block).

Note: `best` resolves to Fable when the account has access, otherwise to the latest Opus. If Fable access has ended permanently, switch the mapping via `/workflow-decisions top-tier` so this tier compensates with higher Opus effort.
