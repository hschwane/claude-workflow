---
name: workflow-decisions
description: View or change a workflow decision (testing scope, branching, deploy target, ci-on-claude, release-runner, pause threshold, …) — edits the live value and keeps docs/workflow/decisions.md in sync
argument-hint: "[setting | natural-language change] — e.g. \"ci-on-claude\" | \"testing scope\""
disable-model-invocation: true
---

# Workflow Decisions

`docs/workflow/decisions.md` is the **record** of every tunable workflow setting. Each setting has a **Live in** location — usually a project doc (`quality.md`, `lifecycle.md`, `release.md`, `deploy.md`, `.claude/memory/decisions.md`) that the skills read at runtime (e.g. `/commit` reads `ci-on-claude`, `/release` reads `release-runner`). This skill keeps the record and the live location in sync: it edits both together, in one commit.

(Distinct from `.claude/memory/decisions.md`, which records *architecture* decisions about the code — this skill only touches the *workflow* settings.)

## Usage
```
/workflow-decisions                          # list settings, pick one to change
/workflow-decisions ci-on-claude             # jump straight to a setting
/workflow-decisions "run CI on my commits too for this library"
/workflow-decisions "release through CI to keep publish secrets off my machine"
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
  (in a chat message) which one to change. Then ask for the new value, offering the documented
  **Options** as choices.
- **A setting name** (`testing scope`, `branching`, `deploy target`, `ci-on-claude`, `release-runner`, …) —
  show its current value and ask for the new one (offer the **Options**).
- **A natural-language change** — map it to one or more concrete setting edits yourself.
  State your interpretation as *"You want: {setting} → {new value}"* and, unless in
  unsupervised mode, confirm before applying.

**For changes that weaken a gate or reduce coverage** — e.g. dropping a testing level, turning
off CI on a shared repo — state the implication to the user before applying (in unsupervised
mode: note it in the report, still apply).

Validate the new value against the **Options** for that setting. If it is out of range or
ambiguous, ask again rather than guessing.

### 3. Apply the change (live value first, then the record)

For each setting being changed:

1. **Edit the Live in target.** Open the file named in the setting's **Live in** line and
   change the value in place. Preserve the surrounding format exactly — for table-based
   settings (e.g. a table) edit only the affected cells; for prose settings
   (e.g. branching model, testing scope) replace only the value.
   - Some targets are docs, not skills (`docs/workflow/quality.md`, `docs/workflow/release.md`,
     `.claude/memory/decisions.md`) — edit those the same way.
   - The **usage threshold** is runtime state; do not edit files for it — tell the user to run
     `/unsupervised on {threshold}`.
2. **Update `docs/workflow/decisions.md`.** Change that setting's **Current** value to match
   what you just wrote, and bump the `Last updated:` date to today.
3. If a setting's live value appears in more than one place (referenced in
   several places), update every occurrence so nothing drifts.

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
{implication note, if the change weakens a gate}
Committed.
```

## Notes
- This skill operates on the project's own copy of the workflow (`.claude/skills/`,
  `docs/workflow/`, `.claude/memory/`). Each project can carry its own tuning.
- `docs/workflow/decisions.md` is documentation, not a runtime input — editing it alone
  changes nothing until the matching **Live in** value is also changed. Always change both
  (this skill does).
