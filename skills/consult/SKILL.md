---
name: consult
description: Get a stronger second opinion from the top-tier `advisor` agent — a hard decision, a design/architecture idea, a debugging angle, or when unsure of the best approach. You stay on your own model (no switch, no cache churn) and delegate the reasoning with a focused question + context. Use PROACTIVELY when stuck (two failed attempts at the same problem), on an architecture/security/correctness call, or genuinely unsure between approaches.
argument-hint: "<question, decision, or problem to think through>"
---

# Consult (Advisor)

Delegate a hard piece of *thinking* to the top-tier `advisor` agent while **you stay on your own model** — no model switch, so the session prompt cache is untouched. It's not only for final decisions: reach for it for design/architecture ideas, a fresh debugging angle when you've stalled, choosing between approaches, or a security/correctness judgement you don't want to guess.

The division of labour is the whole point: **you do the cheap work** (you're cached and you have the scout agents) — frame the question, brief the situation, gather any missing facts — and **the advisor does the one expensive thing**: the hard reasoning. It reasons on a curated brief, not the whole conversation.

## Instructions

### 1. Formulate the question
Write the single, specific question the advisor must answer — sharp enough to act on (e.g. "one service or split read/write paths for FEAT-012?", not "thoughts on the architecture?"). This is the first thing it sees.

### 2. Brief the situation
A concise picture: what's being built, what you've already tried, the symptoms/constraints, and the fork in the road. Keep it to what bears on the question.

### 3. Gather more only if the answer needs it
If answering well needs facts you don't already have in context, get them *now, cheaply, on your own model*: invoke `code-explorer` (understand code) or `text-scout` (extract/summarize text). Their digests come back **with source references** — keep those intact; they become the advisor's map.

### 4. Assemble the context and delegate
Take everything relevant **from the current context** — code excerpts (verbatim where it matters), the scout/explorer digests with their citations, decisions, error output — and pass it to the `advisor` agent up front, together with the question and briefing. This is a bit more up-front context than a bare prompt, but far cheaper than switching model and re-reading the entire session twice. Hand it over as:

> **QUESTION:** {the sharp question from step 1}
> **BRIEFING:** {the situation from step 2}
> **CONTEXT:** {relevant excerpts + scout/explorer digests with their `file:line` sources + decisions/errors}

The advisor reasons on this, and if it needs more it follows the source references in the context to read the rest itself (it's read-only over the repo). It returns a recommendation or ideas with rationale and rejected alternatives — advice, not implementation.

### 5. Act on the advice and record it
You own the outcome. Apply the advice (or decide against it — it's advice). **If it resolved an actual decision**, append a dated entry to `.claude/memory/decisions.md` (question → decision → why) and suggest an ADR if it shapes architecture. For pure ideation or a debugging pointer that didn't settle anything yet, no record is needed — just continue the work with the new angle. If the advisor said the call needs information only the user has, surface that as a `[USER]` question or a `## Blocked` note rather than guessing.

**Fallback:** if a consult genuinely needs the *full, verbatim* live context on the top model (rare — the brief is usually better), you can instead switch manually with `/model best` for a turn. The default `/consult` path keeps you cached and delegates.
