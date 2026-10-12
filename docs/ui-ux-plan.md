# UI/UX overhaul — plan

Status: **planning** (interview in progress). Nothing here is implemented yet.

## The problem

UI gets built, the user spends a long time explaining what they actually need, Claude writes
tickets and implements things the user again does not like, and the loop never converges.

Diagnosis: `templates/guidelines/ui-frontend.md` already prescribes most of the right *policy*
(mockup first, capture a project design system, keep `prototype.html`), but none of it is
*machinery*: no canonical path, no skill creates the doc, `/plan` never reads it, nothing checks
it. Design intent lives only in chat, so every ticket renegotiates taste from zero.

## Decisions

| # | Decision |
|---|---|
| D1 | **One style guide per project**, project-owned, in `docs/design/` (the guide + `prototype.html` + whatever the project needs alongside). One row in `docs/dev/README.md` points at it. |
| D2 | **Structure is free per project.** The plugin gives *recommendations* on what a style guide should decide and pin down (e.g. design variables, layouts, components and their states, copy/tone, interaction rules, accessibility) — not a fixed template. |
| D3 | **When it is created:** when Claude and the user settle the first *real* UI together. Before that, early experimental versions may use a plain test UI and need no style guide. |
| D4 | **Mockup process: diverge, then converge.** 2–3 deliberately different variants of one representative screen, the user picks or mixes, then the chosen one is iterated. Replaces the single-mockup-iterated wording in `ui-frontend.md`. |
| D5 | **Rejections do not automatically become rules.** Whether a correction is a general rule for the style guide or a one-off is decided case by case. |
| D6 | **No generic templates** (no shipped `tokens.css`/`base.css`/component library). The user's workflow stays free. Templates only topic-bound, like `templates/ui/changelog-template.html` for `changelog.md`; none new for now. |
| D7 | **More general UX guidance** in the guidelines, analogous to the coding guidelines: empty/loading/error states, forms and validation, feedback on actions, confirmation of destructive actions, copy quality (no placeholder or filler text). |
| D8 | **Who reads the style guide: `/plan`.** `/implement` and QS get the details through the spec. Instead of copying, the spec may *reference* specific parts of the style guide where relevant. |
| D9 | **UI QS step.** Checks all three levels: (a) fidelity to the spec incl. the style-guide parts it references, (b) UX basics (D7), (c) design judgement — coherence and consistency with the rest of the app. **Judged by an agent** against spec + style guide. **Runs only once a style guide exists, on every ticket with a UI share.** Findings: **Claude fixes and re-checks.** |

## Open mechanics (proposals, to confirm)

- **M1 Judge:** screenshots are taken by `smoke-tester` (it already drives the app via `dev.sh`); judging is a separate read-only agent with vision, because design judgement is not a blackbox pass/fail.
- **M2 Loop cap:** fix + re-check at most 2 rounds, then remaining findings go to the user — an uncapped loop reproduces the original problem.
- **M3 Level (c) must be grounded:** a design finding cites the style guide or an existing screen it is inconsistent with. Ungrounded taste is not a finding, or Claude "fixes" towards its own taste.
- **M4 Trigger:** `/plan` marks a UI share in the spec frontmatter, so `/verify` decides mechanically.
- **M5 Independent of `review-depth`.**
- **M6 No browser / no runnable UI:** skipped with a stated reason, never silently.

## Implied work (to be confirmed once the mechanics are settled)

- `ui-frontend.md`: canonical path (D1), style-guide recommendations (D2), timing (D3), diverge/converge (D4).
- New or extended guideline for general UX rules (D7).
- `/plan`: read `docs/design/` for tickets with a UI share; reference rather than copy (D8); note "test UI, no style guide yet" where D3 applies.
- Scaffolder/onboard: create `docs/design/` (stub) and the `docs/dev/README.md` row; `delivery.json` ownership = project.
- `_check_consistency.py`: the path is named identically everywhere; `/plan` mentions it.
