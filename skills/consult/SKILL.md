---
name: consult
description: Consult the top-tier model (the "advisor") on a hard decision while keeping the session on a cheap model. Use PROACTIVELY when stuck (two failed attempts at the same problem), facing an architecture- or security-relevant decision, or genuinely unsure between approaches — per the Adaptive Routing Policy, consult BEFORE escalating the working tier. Runs inline with the full session context; cost is one elevated turn.
argument-hint: "<question or decision to resolve>"
model: best
effort: medium
---

# Consult (Advisor)

You are now on the top tier for the rest of this turn, with the full session context. This is a consultation, not a work session — no implementation on this tier.

1. **Ground yourself.** Read `.claude/memory/decisions.md` and, if the question is architectural, `docs/dev/architecture.md` plus any relevant ADR in `docs/dev/adr/`.
2. **Resolve the question.** Deliver a clear recommendation with rationale (2–6 sentences) and the rejected alternatives in one line each. If the question can't be resolved without information only the user has, say so explicitly — that becomes a `[USER]` question or a `## Blocked` note, not a guess.
3. **Record it.** Append a dated entry to `.claude/memory/decisions.md` (question → decision → why). Suggest an ADR if the decision shapes architecture.
4. **Step back down.** Re-invoke the route skill for the active ticket's tier (from the spec routing block or the checkpoint `tier:` line). No active ticket → invoke `route-sonnet-medium`. Then continue the interrupted work.
