---
name: workflow-decisions
description: View or change a workflow decision (refine sizing, testing scope, review tier, branching, auto-merge, …) — edits the live value in the skill and keeps docs/workflow/decisions.md in sync
argument-hint: "[setting | natural-language change] — e.g. \"refine sizing\" | \"make large tickets use fable\""
disable-model-invocation: true
---

# Workflow Decisions

`docs/workflow/decisions.md` is the human-readable **record** of every tunable workflow
setting this project has decided on. For speed the *live* value of each setting is written
directly into the skill that uses it — skills never read `decisions.md` at runtime. This
skill is what keeps the two in sync: it edits the live value **and** updates
`decisions.md` together, in one commit.

(Distinct from `.claude/memory/decisions.md`, which records *architecture* decisions about
the code — this skill only touches the *workflow* record in `docs/workflow/decisions.md`.)

## Usage
```
/workflow-decisions                          # list settings, pick one to change
/workflow-decisions refine sizing            # jump straight to a setting
/workflow-decisions "make large tickets use fable and manual approval"
/workflow-decisions "review only small diffs, always full review otherwise"
```

## Instructions

### 1. Load the decisions record
Read `docs/workflow/decisions.md`. It lists every setting with its **Live in** location, its
**Current** value, and the allowed **Options**. This is your map: every change you make
edits both a **Live in** target and the matching **Current** entry here.

If `docs/workflow/decisions.md` does not exist: the project predates the central record. Offer
to create it now. Prefer `/workflow-update`, which recreates it from the current plugin
template and reconciles values. If you build it here directly, reconstruct each entry (What /
Live in / Current / Options) by reading the actual **Live in** locations in this project — do
**not** assume a `templates/` copy exists, since the plugin's templates are not shipped into
projects. If the user declines, stop.

### 2. Resolve intent → a concrete change

- **No argument** — present the settings from `decisions.md` grouped by area and ask
  (AskUserQuestion) which one to change. Then ask for the new value, offering the documented
  **Options** as choices.
- **A setting name** (`refine sizing`, `testing scope`, `branching`, `review tier`, …) —
  show its current value and ask for the new one (offer the **Options**).
- **A natural-language change** — map it to one or more concrete setting edits yourself.
  State your interpretation as *"You want: {setting} → {new value}"* and, unless in
  unsupervised mode, confirm before applying.

**For changes that weaken a gate or reduce coverage** — e.g. disabling a reviewer, dropping
a testing level, widening the light-review threshold, turning auto-merge on for a protected
branch — consult the `workflow-coach` subagent first for the implications, and surface them
to the user before applying (in unsupervised mode: note them in the report, still apply).

Validate the new value against the **Options** for that setting. If it is out of range or
ambiguous, ask again rather than guessing.

### 3. Apply the change (live value first, then the record)

For each setting being changed:

1. **Edit the Live in target.** Open the file named in the setting's **Live in** line and
   change the value in place. Preserve the surrounding format exactly — for table-based
   settings (e.g. the refine sizing table) edit only the affected cells; for prose settings
   (e.g. branching model, testing scope) replace only the value.
   - Some targets are docs, not skills (`docs/workflow/quality.md`, `docs/workflow/release.md`,
     `.claude/memory/decisions.md`) — edit those the same way.
   - The **usage threshold** is runtime state; do not edit files for it — tell the user to run
     `/unsupervised on {threshold}`.
2. **Update `docs/workflow/decisions.md`.** Change that setting's **Current** value to match
   what you just wrote, and bump the `Last updated:` date to today.
3. If a setting's live value appears in more than one place (the sizing table is referenced in
   several sub-steps of `/refine`), update every occurrence so nothing drifts.

**Consistency check:** after editing, re-read the **Live in** location and the **Current**
entry and confirm they now state the same value. If they disagree, fix before committing.

### 4. Commit
```bash
git add docs/workflow/decisions.md .claude/skills .claude/memory docs/workflow
git commit -m "chore(workflow): decide {setting} — {old} → {new}"
```
Only stage the files you actually changed.

Skill edits take effect the next time the skill is invoked — **no `/reload-skills` needed**
(that command is only for discovering newly added skills/agents, not content changes).

### 5. Report
```
Decision updated ✓
{setting}: {old} → {new}
  Live value: {Live in path}
  Record:     docs/workflow/decisions.md
{implications from workflow-coach, if any}
Committed.
```

## Notes
- This skill operates on the project's own copy of the workflow (`.claude/skills/`,
  `docs/workflow/`, `.claude/memory/`). Each project can carry its own tuning.
- `docs/workflow/decisions.md` is documentation, not a runtime input — editing it alone
  changes nothing until the matching **Live in** value is also changed. Always change both
  (this skill does).
