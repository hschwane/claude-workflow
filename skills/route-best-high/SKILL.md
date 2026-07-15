---
name: route-best-high
description: Set the working tier to the top-tier model at high effort for the rest of the current turn — reserved for refining and reviewing large tickets. Never used for implementation or test writing. Invoke when a spec routing block or a workflow skill directs it. Reverts automatically on the next user prompt.
model: best
effort: high
---

# Routing: top-tier / high

<!-- top-tier mapping: fable (current). Tunable via /workflow-decisions "Top-tier mapping":
     fable            → model: best, effort: high   (best = Fable if available, else latest Opus)
     opus-compensated → model: opus, effort: xhigh  (use when Fable access has ended, to compensate with effort) -->

Tier applied for the rest of this turn. Continue immediately with the task in progress — do not summarize, restart, or re-plan.

If a ticket is in progress, keep the checkpoint current: set `tier: best-high` in the `## In Progress` block of `.claude/memory/context-{branch}.md` (add a short reason if this deviates from the spec's routing block).

Note: `best` resolves to Fable when the account has access, otherwise to the latest Opus. If Fable access has ended permanently, switch the mapping via `/workflow-decisions top-tier` so this tier compensates with `xhigh` effort on Opus.
