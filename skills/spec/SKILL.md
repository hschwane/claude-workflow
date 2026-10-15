---
name: spec
description: Turn whatever the user gives — a single sentence, a rough idea, or a prepared document — into one or more specs that /wf:deliver can build and its critic can judge. Use when the user wants work written up as specs for later delivery.
argument-hint: "<idea, request, or path to a document>"
---

# Spec

A spec is a small design document with one job: `/wf:deliver` builds it, and a critic with fresh
context judges the result against it. This skill makes specs from whatever the user hands over —
nothing more, nothing less. Input: `$ARGUMENTS`.

## 1. Read the context
- The settings block in `CLAUDE.md` (`<!-- wf:settings -->`): `spec-mode` decides storage. No
  block → `none`.
- For anything beyond a trivial change, load the `guidelines` skill and read the guidelines whose
  trigger matches.
- UI work: if `docs/design/style-guide.md` exists, the spec references the parts that apply.

## 2. Cut it into specs
**One spec = one coherent change that a single `deliver` run can finish and the critic can judge
in one verdict.** Small steps, not epics. A prepared document usually becomes several specs, in
the order they should be built; a sentence usually becomes one. When a piece would be too big to
judge at once, split it. Each spec's `source` points at what it came from — the user's words, or
the document and its section — so the critic can judge against the original, not only the spec.

## 3. Write each spec — as much as the change needs
**Trivial** (the diff fits in a sentence: a renamed label, a fixed typo, one guard clause): goal in
one line, one or two acceptance criteria, the command that proves it. Nothing else.

**Normal:**
- **Goal** — what and for whom, and the `source`.
- **Acceptance criteria** — observable: an action → a checkable result. Every expected value comes
  from the source or an outside authority, **never from running the code**. Where a right answer
  exists outside the code (a calculation, a format, a protocol), name it and anchor at least one
  criterion to it.
- **Reference**, only where quality is a matter of comparison (a UI, a text, an output): named,
  fetchable, comparable — something the critic can open next to the result.
- **Scope** — what is in, what is out, what must not change.
- **Verification** — the command or steps that prove it. For UI: the screens and states to capture,
  **including the results of actions** (after saving, after deleting, after an invalid submit with
  other fields filled), at the style guide's viewports.
- **Docs** — which docs this makes untrue, or "none".

What cannot be filled without guessing becomes one batched question to the user. Unattended, take
the most reasonable reading and list it under *Assumptions*.

## 4. Store them, by spec mode
- **`files`** — `docs/specs/<ID>-<slug>.md`, IDs `S-001` upward (next free number):
  ```markdown
  ---
  id: S-001
  title: Short imperative title
  status: ready        # draft | ready | in-progress | done
  source: user request 2026-10-15   # or docs/design/booking.md#editing
  ui: no               # yes when a graphical UI changes
  ---
  ## Goal
  ## Acceptance criteria
  ## Verification
  (Reference, Scope, Docs, Assumptions — only when the spec needs them)
  ```
  Commit them on their own (`docs(specs): …`).
- **`issues`** — one GitHub issue per spec, the same sections as body, label `wf-spec` plus a status
  label `wf:draft` / `wf:ready` / `wf:in-progress`; closed means done.
- **`none`** — show the specs in the conversation; `deliver` takes them from there.

A spec is `ready` when its sections are filled and no question is open; otherwise `draft`.

## 5. Report
The specs with their IDs and order, the guidelines that applied, questions asked or assumptions
made, and the next step: `/wf:deliver <ids>`.
