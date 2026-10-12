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

## Mechanics (decided)

- **M1 Two-stage judging:** `smoke-tester` drives the app, takes screenshots and gives the **first** UI feedback itself. When it is unsure, or something stands out, the screenshots go to a separate reviewer for a second look. (Proposal: reuse the existing read-only `reviewer` agent in a UI mode rather than adding an eighth agent.)
- **M2 Loop cap: 4 rounds** of fix + re-check, then remaining findings go to the user. (Normal code review has no numeric cap today — `/implement` says "re-run `/verify` until clean", bounded only by "same failure twice → `/consult`".)
- **M3 Valid findings** are: a violation of the spec or the style guide; inconsistency with an existing screen; **or** something that is simply hard to use, or does not match reference applications or established best practice. A finding does not need a rule that already exists in the project — but it must say *what* is wrong and *why* (which practice, which usability problem), not just "would look nicer".
- **M4 Trigger:** `/plan` marks a UI share in the spec frontmatter (`ui: yes`), so `/verify` decides mechanically.
- **M5 Independent of `review-depth`.**
- **M6 No browser / no runnable UI:** skipped with a stated reason, never silently.

## Implied work (proposed scope)

- `ui-frontend.md`: canonical path (D1), style-guide recommendations (D2), timing (D3), diverge/converge (D4).
- New or extended guideline for general UX rules (D7).
- `/plan`: read `docs/design/` for tickets with a UI share; reference rather than copy (D8); note "test UI, no style guide yet" where D3 applies.
- Scaffolder/onboard: create `docs/design/` (stub) and the `docs/dev/README.md` row; `delivery.json` ownership = project.
- `/verify` (ticket mode): the UI QS step — condition (style guide exists + `ui: yes`), smoke-tester screenshots + first judgement, reviewer escalation, 4-round cap, skip-with-reason (D9, M1–M6).
- `smoke-tester.md`: screenshots + UI feedback against spec, referenced style-guide parts and D7; flag uncertainty for escalation.
- `reviewer.md`: UI mode — judge screenshots against spec, style guide, usability and best practice (M3).
- `spec.md.template`: `ui:` frontmatter field.
- `_check_consistency.py`: the path is named identically everywhere; `/plan` mentions it; `ui:` is in the template and read by `/verify`; the 4-round cap is stated once.
