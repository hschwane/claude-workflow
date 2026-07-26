# Project notes (project-owned — the workflow never overwrites these)

Standing rules, conventions and decisions **specific to this project** that should shape future work: a local convention, a deliberate deviation from a workflow preference, a "we always do X here because Y".

This is the counterpart to `.claude/preferences/`, which is plugin-owned and replaced on every update. Nothing here is ever touched by `/workflow-update`.

## What goes where

| | Put it here (`project-notes/`) | Put it elsewhere |
|---|---|---|
| A rule that should influence **future** work in this project | ✅ | |
| A deviation from a workflow preference you want to keep | ✅ | |
| A general "how X is done" rule that isn't project-specific | | it's a workflow preference — propose it upstream |
| A **dated record** of a decision that was made | | `.claude/memory/decisions.md` (the log) |
| An architecture decision with lasting structural consequences | | `docs/dev/adr/` |
| Commit/branch/ID/version conventions | | `docs/workflow/conventions.md` |

The distinction against `.claude/memory/decisions.md` is tense: that file **logs what was decided**, dated and append-only. A project note **states what to do from now on**, and gets read whenever its trigger matches.

## How it works

Same progressive disclosure as workflow preferences:

1. Create `.claude/project-notes/<topic>.md` with the actual rule — specific and concise.
2. Add one row to `INDEX.md`:

   | When the task involves… | Read |
   |---|---|
   | The billing module, invoices, dunning | `.claude/project-notes/billing.md` |

Or just tell Claude "remember this for X in this project" — it writes the file and the row.

`INDEX.md` is not auto-loaded; a note's body is read only when its trigger matches.

## Precedence

A project note **outranks a workflow preference** on the same subject — it's the more specific, deliberately-authored rule.

**Name the preference you're overriding.** A note that says "we do X here, not what `railway.md` recommends, because Y" is a settled decision: Claude applies it and moves on. A note that happens to contradict a preference without saying so reads as an accident — Claude will surface the conflict and ask, then write the answer back here so it's settled from then on. Naming the override is what stops the same question coming back.

## Keep triggers concrete

A good trigger names the tech, feature or file patterns Claude will actually recognize in a task ("Stripe / payments / webhooks", "database migration", "the reporting module"). Vague triggers ("good code") don't help Claude know when to look.
