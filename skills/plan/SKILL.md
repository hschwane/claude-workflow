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

**Check preferences:** read the preferences index(es) — the project's `.claude/preferences/INDEX.md` and, if present, the user-global `~/.claude/preferences/INDEX.md` (cross-project prefs like "Railway", "React"). For every trigger that matches a ticket's technology/feature, read that preference file. **Treat it as a recommendation, not a rule to apply blindly** — judge it against this project's actual scale, constraints, and existing patterns. Adapt what fits to the acceptance criteria / approach / constraints; for any part (or all of it) that genuinely doesn't fit, deliberately reject it with a reason rather than forcing it in. Either way, **reference the outcome in the spec** — an `Applied preferences:` line listing the file(s), with a short note on anything adapted or rejected and why (e.g. `.claude/preferences/background-jobs.md — adapted: always-on deploy here, so no scale-to-zero wakeup path needed`, or `.claude/preferences/service-architecture.md — rejected: single 150-line script, full layering would be overkill`). Load only the matching files — that's the point of the index. (Project-level wins over global on conflict.) If no preference matches, add nothing.

### 2. Write the spec

For each ticket, fill the spec template (`docs/specs/` uses `spec.md.template`) with:

- **Goal / user story** — what and for whom, in one or two sentences.
- **Acceptance criteria** — **observable** statements (an action → an expected, checkable result: "run `x --foo` → prints Z"; "POST /bar → 200 + `{id}`"; "click Save → row persists + toast"). These are the contract `/verify` checks against, so they must be demonstrable, not vague ("should work").
- **Approach / interfaces** — the key interfaces or signatures to add/change, and a short note on the approach. Enough to implement without re-deciding architecture mid-build; not a full design doc.
- **Subtasks** — an ordered checklist of implementable steps, each a green-committable unit.
- **Test scope** — which levels apply (unit / +integration / +e2e) for this ticket, within the project default (`docs/workflow/quality.md`). Quality over quantity — the important behaviors.

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
- If `github_issue` set and `GitHub integration` is not `no`: move labels to `ready`.
- Commit (`docs(specs): plan {id}  [skip ci]`).

### 6. Report
```
Planned ✓  {ids}
Ready: {list}   Deferred to new tickets: {list or none}   Assumptions made (unsupervised): {list or none}
Next: /implement {first id}  (or /ship continues)
```
