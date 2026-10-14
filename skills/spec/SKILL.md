---
name: spec
description: Write a design doc for something big, derive self-contained specs from an idea or a design doc, or enrich a terse request into a precise, checkable bar. Use when the user wants to plan work ahead, turn a design doc into implementable pieces, or sharpen a short prompt before /wf:deliver or /wf:gauntlet.
argument-hint: "design <topic> | <idea or design-doc path> | enrich <request>"
---

# Spec

Turns intent into something a builder can implement and a critic can judge. Three modes, picked
from the input:

| Input | Mode | Output |
|---|---|---|
| `design <topic>`, or an idea too big for a few specs | **design** | `docs/design/<topic>.md` |
| an idea, or a path to a design doc | **specs** | one spec per independently deliverable piece |
| `enrich <request>`, or called by `deliver`/`gauntlet` on a terse prompt | **enrich** | a bar, shown (and stored as a spec if the spec mode stores specs) |

## First, always
- Read the settings block in `CLAUDE.md` (`<!-- wf:settings -->`): `spec-mode` decides storage.
  No block → `none`.
- Load the `guidelines` skill and read every guideline whose trigger matches. A guideline is a
  recommendation: apply it, adapt it, or reject it with a reason you write into the spec.
- For UI work: if `docs/design/style-guide.md` exists, the spec references the parts that apply.
  If the project has no style guide yet and this is its first real UI, the design doc includes the
  design pass from the `ui-frontend` guideline (variants → the user picks → style guide).

## The bar — what every spec and every enrichment must contain
A critic will judge the result against this, with fresh context, so vagueness here becomes a rubber
stamp later.
- **Goal** — what and for whom, one or two sentences, and the **source** it serves (the user's
  words, the design doc and section, the reference).
- **Acceptance criteria** — observable: an action → a checkable result. Every expected value comes
  from the spec's source or an outside authority, **never from running the code**. Where a right
  answer exists outside the code (a calculation, a format, a protocol), name the source and anchor
  at least one criterion to it.
- **Reference** where quality is a matter of comparison (a UI, a text, an algorithm's output):
  named, fetchable, comparable — something the critic can open and put next to the result.
- **Scope** — what is in, what is explicitly out, what must not change.
- **Verification** — the command or the steps that prove it end to end. For UI: the screens and
  states to capture, **including the results of the actions** (after saving, after deleting,
  after an invalid submit with other fields filled), at the style guide's viewports.
- **Docs** — one line: which docs this makes untrue, or "none".

Enriching a terse request means filling exactly these from the context you have. What you cannot
fill without guessing becomes one batched question to the user — unless the caller runs unattended,
then take the most reasonable reading and list it under *Assumptions*.

## Design docs
For work too big for a handful of specs: interview the user (batched questions, the hard parts
first), then write `docs/design/<topic>.md` — goal and users, main flows, constraints, non-goals,
acceptance for the whole, open questions. It is the original bar for every spec derived from it and
for `gauntlet`. Specs link back to it; they never replace it.

## Storage, by spec mode
- **`files`** — `docs/specs/<ID>-<slug>.md`, IDs `S-001` upward (next free number):
  ```markdown
  ---
  id: S-001
  title: Short imperative title
  status: draft        # draft | ready | in-progress | done
  source: docs/design/booking.md#editing   # or "user request <date>"
  ui: no               # yes when a graphical UI changes
  ---
  ## Goal
  ## Acceptance criteria
  ## Reference          (if any)
  ## Scope
  ## Verification
  ## Docs
  ## Assumptions        (only when unattended)
  ```
- **`issues`** — a GitHub issue per spec with the same sections as body, label `wf-spec`, and a
  status label `wf:draft` / `wf:ready` / `wf:in-progress`; closed means done.
- **`none`** — show the spec in the conversation; the caller keeps it in its run.

A spec is `ready` when every section is filled and no question is open. Commit spec files on their
own (`docs(specs): …`).

## Report
The specs or the design doc with their IDs, which guidelines applied, the questions you asked or the
assumptions you made, and the next step (`/wf:deliver <ids>` or `/wf:gauntlet <doc>`).
