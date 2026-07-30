# Workflow guidelines (plugin-owned — do not edit)

Standing per-technology / per-feature recommendations shipped **by the workflow plugin**: "how this kind of thing is done" notes that would bloat the root `CLAUDE.md` if they were always loaded.

**This folder is replaced wholesale on every `/workflow-update`.** Local edits here are lost. That is deliberate — it's how a fix to a guideline reaches every project instead of freezing at whatever version happened to be installed first.

**Project-specific rules, notes and decisions belong in `.claude/memory/decisions.md`**, which the update never touches. If you want to change how something is done *in this project*, record a dated decision there naming the guideline it departs from — don't edit a file here.

## These are recommendations, not rules to apply blindly

A matching guideline is a strong default worth starting from — not a mandate to force onto a project it doesn't fit. Judge it against this project's actual scale and constraints: adapt what fits, and deliberately reject (with a stated reason) whatever doesn't — a 150-line script doesn't need `service-architecture.md`'s full layering. `/plan` records that judgment in the spec.

**An explicit instruction outranks a guideline.** When the user or the project's stated requirements call for something that conflicts, follow the instruction — but say so in chat, naming the guideline being deviated from, so the deviation stays visible. To make it permanent, record it as a dated decision in `.claude/memory/decisions.md`.

**A shipped example that does less than a guideline requires is a gap in that project**, not evidence the guideline should ask for less.

## How it works (progressive disclosure)

- Each guideline is its own file here.
- `INDEX.md` is a **trigger → file** table — the only thing skills read to know what exists. It is not auto-loaded, so it costs nothing until a relevant task.
- Skills read `INDEX.md` at the moments it matters (`/plan`, `/implement`, `/project-init`, `/project-onboard`). A guideline **body** is read only when its trigger matches.
- Both indexes are read together: this one and `.claude/memory/decisions.md`.

## Which files are here

**All of them.** The whole library is installed in every project and refreshed on every update. A guideline whose subject this project has never touched costs nothing: nothing here is auto-loaded, and `INDEX.md` is read only at plan/implement time.

That is deliberate. Relevance is a property of the *task*, not of the project — and the trigger table already decides it. Filtering again at install time only meant a project that grew a chart or a background job later had to wait for an update run to notice and offer the guideline, which is exactly the case that kept being missed.

So there is no "install this one" step, and removing a file here does not stick — the next update puts it back. If you don't want a guideline's advice in this project, record a dated decision in `.claude/memory/decisions.md` naming it. That is the mechanism, and it survives updates.
