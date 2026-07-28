---
name: plan
description: Turn a raw backlog draft into a ready-to-implement spec — one light planning pass. Surfaces open questions (batched up front for multiple tickets), never silently drops scope. Pass multiple IDs to plan a batch.
argument-hint: "FEAT-001 [FEAT-003 ...]  (one or more backlog IDs)"
---

# Plan

Turns a raw draft into a spec an implementer can build from — in a single light pass, not an adversarial multi-round process. The goal is a clear contract, not exhaustive ceremony.

## Usage
```
/plan FEAT-001
/plan FEAT-001 FEAT-003 BUG-007     # batch: all questions asked once, up front
```

## Instructions

### 1. Gather context (once)
Read: the draft spec(s) from `docs/specs/backlog/`, `docs/VISION.md` (if present), root `CLAUDE.md`, and `docs/dev/architecture.md` (if present). For anything touching unfamiliar code, invoke the `code-explorer` agent for a briefing (relevant files, interfaces, patterns, pitfalls) instead of reading widely yourself. (For a genuinely large codebase you can first fan out `text-scout`s from here for a cheap overview, then aim `code-explorer` at the details — see the exploration note in `CLAUDE.md`.)

**Check guidelines and project memory:** read `.claude/memory/decisions.md` and `gotchas.md` — load each file's head first, and read on only if a topic in its index line matches this ticket. A dated decision that names the guideline it departs from is settled: apply it, don't re-ask. Then read the indexes — `.claude/guidelines/INDEX.md`, and if present the user-global `~/.claude/guidelines/INDEX.md`. For every trigger that matches a ticket's technology/feature, read that file.

A **dated decision in `.claude/memory/decisions.md` outranks a guideline** on the same subject.
- The decision **names the guideline** it departs from → settled. Apply it, record it in the spec, **don't re-ask** — re-asking an answered question is the failure this split exists to prevent.
- It contradicts a guideline **without acknowledging it** → the conflict may be unintended (the guideline may have changed under it). **Ask**, batched with the other `[USER]` questions, and write the answer back into `decisions.md` so it is settled from then on.

If instead the **user or the ticket's explicit requirements** call for something that conflicts with a matching guideline (not Claude's own scale/fit judgment), follow the explicit instruction — the user outranks the guideline — but **say so plainly in chat**, naming the guideline and noting the conflict, not just in the spec's `Applied guidelines:` line.

### 2. Write the spec

For each ticket, fill the spec template (`docs/specs/` uses `spec.md.template`) with:

- **Goal / user story** — what and for whom, in one or two sentences.
- **Acceptance criteria** — **observable** statements (an action → an expected, checkable result: "run `x --foo` → prints Z"; "POST /bar → 200 + `{id}`"; "click Save → row persists + toast"). These are the contract `/verify` checks against, so they must be demonstrable, not vague ("should work").
- **Approach / interfaces** — the key interfaces or signatures to add/change, and a short note on the approach. Enough to implement without re-deciding architecture mid-build; not a full design doc.
- **Subtasks** — an ordered checklist of implementable steps, each a green-committable unit.
- **Test scope** — which levels apply (unit / +integration / +e2e) for this ticket, within the `testing-scope` setting in `CLAUDE.md`. Quality over quantity — the important behaviors.

### 3. Scope discipline — never defer the core

The acceptance criteria must cover the ticket's **full intent**, not a convenient subset. The goal of the ticket is in scope, period.

- **NEVER defer, cut, or mark "out of scope" anything the ticket's goal requires** — the core functionality, the hard part, an acceptance criterion, the error/edge handling those criteria imply, or "the rest of the feature." Difficulty, size, or effort is **not** a reason to scope something out. If it's what the ticket is for, it's in.
- "Out of scope" means **only** genuinely separable work the ticket never asked for — an unrelated enhancement, a nice-to-have that no criterion depends on. If in doubt, it's **in** scope.
- If a ticket is genuinely too big to do in one go, do **not** silently narrow it. Say so during the up-front question batch and let the user decide how to split it — an explicit split, not a quiet deferral of the important half.
- Any deferral that does happen (rare, peripheral only) → create the follow-up draft in `backlog/` and note it so it surfaces in the report. Never a silent drop.
- Genuine unknowns become `[USER]` questions (below), not silent assumptions or scope cuts.

### 4. Questions — batched up front
If resolving the spec needs the user's input, collect every `[USER]` question.

- **Single-ticket** mode: ask now in chat (plain message).
- **Multi-ticket** mode: **plan all tickets first, collecting questions across all of them, then ask the whole set together** in one chat message (a numbered list), before returning. Be thorough — surface every decision that would otherwise need the user *later* (scope boundaries, ambiguous acceptance criteria, design/tech forks), because after this batch the caller (e.g. `/ship`) runs autonomously and won't ask again. Then finish every spec. The user answers once and walks away.
- **Unsupervised** mode: don't ask — apply the most reasonable default, note the assumption in the spec, and continue.

### 5. Mark ready
When a spec has a goal, observable acceptance criteria, an approach, subtasks, and no open questions:
- Set frontmatter `status: ready`; `git mv docs/specs/backlog/{file} docs/specs/ready/{file}`.
- If `github_issue` is set and the `github` setting in `CLAUDE.md` is not `no`: move labels to `ready`.
- Commit: `git add docs/specs/ && git commit -m "docs(specs): plan {id}  [skip ci]"` — stage the specs directory explicitly, so unrelated working-tree changes don't land in a `docs(specs):` commit.

### 6. Report
```
Planned ✓  {ids}
Ready: {list}   Deferred to new tickets: {list or none}   Assumptions made (unsupervised): {list or none}
Next: /implement {first id}  (or /ship continues)
```
