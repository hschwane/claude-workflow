# Workflow guidelines (plugin-owned — do not edit)

Standing per-technology / per-feature recommendations shipped **by the workflow plugin**: "how this kind of thing is done" notes that would bloat the root `CLAUDE.md` if they were always loaded.

**This folder is replaced wholesale on every `/workflow-update`.** Local edits here are lost. That is deliberate — it's how a fix to a preference reaches every project instead of freezing at whatever version happened to be installed first.

**Project-specific rules, notes and decisions belong in `.claude/memory/decisions.md`**, which the update never touches. If you want to change how something is done *in this project*, write a project note — don't edit a file here.

## These are recommendations, not rules to apply blindly

A matching guideline is a strong default worth starting from — not a mandate to force onto a project it doesn't fit. Judge it against this project's actual scale and constraints: adapt what fits, and deliberately reject (with a stated reason) whatever doesn't — a 150-line script doesn't need `service-architecture.md`'s full layering. `/plan` records that judgment in the spec.

**An explicit instruction outranks a preference.** When the user or the project's stated requirements call for something that conflicts, follow the instruction — but say so in chat, naming the preference being deviated from, so the deviation stays visible. To make it permanent, record it as a project note.

**A shipped example that does less than a preference requires is a gap in that project**, not evidence the preference should ask for less.

## How it works (progressive disclosure)

- Each preference is its own file here.
- `INDEX.md` is a **trigger → file** table — the only thing skills read to know what exists. It is not auto-loaded, so it costs nothing until a relevant task.
- Skills read `INDEX.md` at the moments it matters (`/plan`, `/implement`, `/project-init`, `/project-onboard`). A preference **body** is read only when its trigger matches.
- Both indexes are read together: this one and `.claude/memory/decisions.md`.

## Which files are here

Only the library guidelines that matched this project at init/onboard time, refreshed on every update. `/workflow-update` offers newly-matching ones as the project grows — it never force-installs a file you removed.
