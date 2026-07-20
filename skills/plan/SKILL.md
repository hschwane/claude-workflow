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
Read: the draft spec(s) from `docs/specs/backlog/`, `docs/VISION.md` (if present), root `CLAUDE.md`, and `docs/dev/architecture.md` (if present). For anything touching unfamiliar code, invoke the `code-explorer` agent for a briefing (relevant files, interfaces, patterns, pitfalls) instead of reading widely yourself.

### 2. Write the spec

For each ticket, fill the spec template (`docs/specs/` uses `spec.md.template`) with:

- **Goal / user story** — what and for whom, in one or two sentences.
- **Acceptance criteria** — **observable** statements (an action → an expected, checkable result: "run `x --foo` → prints Z"; "POST /bar → 200 + `{id}`"; "click Save → row persists + toast"). These are the contract `/verify` checks against, so they must be demonstrable, not vague ("should work").
- **Approach / interfaces** — the key interfaces or signatures to add/change, and a short note on the approach. Enough to implement without re-deciding architecture mid-build; not a full design doc.
- **Subtasks** — an ordered checklist of implementable steps, each a green-committable unit.
- **Test scope** — which levels apply (unit / +integration / +e2e) for this ticket, within the project default (`docs/workflow/quality.md`). Quality over quantity — the important behaviors.

### 3. Scope discipline
- **Default to including** what the ticket implies. Do **not** silently declare things out of scope.
- Deferring work to a separate ticket is allowed but should be the **exception** — when you do, create the follow-up draft in `backlog/` and **note the deferral** so it surfaces in the final report (e.g. `/ship`'s report).
- Genuine unknowns become `[USER]` questions (below), not silent assumptions.

### 4. Questions — batched up front
If resolving the spec needs the user's input, collect every `[USER]` question. In **single-ticket** mode, ask now (AskUserQuestion). In **multi-ticket** mode, gather questions across **all** tickets and ask them in **one batch** at the start, then finish every spec autonomously — so the user answers once and can walk away. In unsupervised mode: don't ask — apply the most reasonable default, note the assumption in the spec, and continue.

### 5. Mark ready
When a spec has a goal, observable acceptance criteria, an approach, subtasks, and no open questions:
- Set frontmatter `status: ready`; `git mv docs/specs/backlog/{file} docs/specs/ready/{file}`.
- If `github_issue` set and `GitHub integration` is not `no`: move labels to `ready`.
- Commit (`docs(specs): plan {id}  [skip ci]`).

### 6. Report
```
Planned ✓  {ids}
Ready: {list}   Deferred to new tickets: {list or none}   Assumptions made (unsupervised): {list or none}
Next: /implement {first id}  (or /ship continues)
```
