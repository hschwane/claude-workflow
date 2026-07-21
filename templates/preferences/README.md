# Preferences

Small, focused preference files for specific **technologies, project types, or features** — the standing "how I like X done" notes that would bloat the root `CLAUDE.md` if they were always loaded.

**These are recommendations, not rules to apply blindly.** A matching preference is a strong default worth starting from — not a mandate to force onto a project it doesn't fit. When a trigger matches, judge the guidance against this project's actual scale and constraints: adapt what fits, and deliberately reject (with a stated reason) whatever genuinely doesn't — e.g. a 150-line script doesn't need `service-architecture.md`'s full layering, and a background job on an always-on deploy doesn't need `background-jobs.md`'s scale-to-zero wakeup path. `/plan` records that judgment call in the spec, not just a bare file reference.

## How it works (progressive disclosure — two levels)

- Each preference is its own file here, e.g. `railway.md`, `react.md`, `stripe.md`.
- `INDEX.md` holds a tiny **trigger → file table** — this is the only thing skills read to know what exists. It is **not** auto-loaded into every session (so even the index costs nothing until a relevant task).
- The workflow skills read `INDEX.md` at the moments it matters — `/plan`, `/implement`, and `/project-init`/`/project-onboard`. For ad-hoc work, Claude reads it when a task touches a specialized area (per the one-line pointer in the root `CLAUDE.md`).
- A **preference body** is read only when its trigger matches — so the detail costs tokens only when actually relevant.

## Adding a preference

1. Create `.claude/preferences/<topic>.md` with the actual guidance (specific and concise).
2. Add one row to `INDEX.md`:

   | When the task involves… | Read |
   |---|---|
   | Railway deploy, `railway.json`, scale-to-zero | `.claude/preferences/railway.md` |

Or just tell Claude "remember this preference for X" — it creates the file and adds the row.

## Keep triggers concrete

A good trigger names the tech/feature/file patterns Claude will actually recognize in a task ("Stripe / payments / webhooks", "database migration", "the reporting module"). Vague triggers ("good code") don't help Claude know when to look.
