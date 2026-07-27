---
name: workflow-update
description: Update the claude-workflow files in this project to a newer plugin version without touching project-specific files
argument-hint: "[version tag, e.g. v1.3.0]"
disable-model-invocation: true
---

# Workflow Update

Updates the claude-workflow plugin files in this project to a newer version without overwriting project-specific files.

## Usage
```
/workflow-update
/workflow-update v1.3.0
```

## Instructions

### 1. Read Current State
Read `.claude/workflow-source.json`:
```json
{ "repo": "https://github.com/...", "version": "1.2.0", "installed": "2026-01-01" }
```
If this file doesn't exist: print an error explaining this project wasn't set up with `/project-init` or `/project-onboard` and offer to create it manually.

### 2. Fetch Latest Version
Clone the workflow repo into a temp directory. Pick the temp path for the shell you are actually using — detect it, don't assume:
- Bash / Git Bash (also on Windows): `UPDATE_DIR="${TMPDIR:-/tmp}/claude-workflow-update"`
- PowerShell: `$UPDATE_DIR = "$env:TEMP\claude-workflow-update"`

If the directory already exists from a previous run, delete it first. Then:
```
git clone --depth 1 {repo_url} {UPDATE_DIR}
```
Get the latest version tag:
```
git -C {UPDATE_DIR} tag --sort=-version:refname | head -1
```

If a target version was specified as an argument: use that instead of latest.

### 3. Show What Changed
- If `{UPDATE_DIR}/CHANGELOG.md` exists: read it and extract the entries between current version and target version.
- Otherwise (the plugin repo ships no changelog): derive the changes from git history. The clone from step 2 is shallow, so fetch history and tags first:
  ```
  git -C {UPDATE_DIR} fetch --unshallow --tags 2>/dev/null || git -C {UPDATE_DIR} fetch --tags
  git -C {UPDATE_DIR} log v{current}..{target} --oneline
  ```
- Display the changes to the user

Check for breaking changes: if the changelog or commit list contains `BREAKING`, `[BREAKING]`, or a conventional-commit `!` marker (e.g. `feat!:`), highlight them prominently.

### 4. Confirm
Ask the user (ask in chat):
- "Update from {current} to {target}? [yes / choose different version / cancel]"

If breaking changes exist, show them explicitly and ask separately: "This update has breaking changes. Review them above. Continue?"

### 5. Apply Update
Copy the **system files** from the temp clone into this project's `.claude/`. Agents and skills are plugin-owned wholesale, so **mirror** them — replace the directory contents AND delete any skill/agent the new version no longer ships (e.g. on the 2.x upgrade: `route-*`, `prioritize`, `brainstorm` skills; `test-writer`, `requirements-engineer`, `tech-planner`, `documentation-writer`, `product-owner`, `workflow-coach`, `test-runner`, `code-reviewer`, `security-reviewer`, `architect-reviewer` agents). Leaving stale files behind is a real bug.
```
# Mirror (delete-then-copy so removed files don't linger):
.claude/agents/          ← mirror temp clone agents/       (removes deleted agents)
.claude/skills/          ← mirror temp clone skills/       (removes deleted skills; {name}/SKILL.md)
.claude/hooks/*.sh       ← copy all from temp clone templates/hooks/*.sh; chmod +x
.claude/memory/.gitignore ← copy from temp clone templates/memory/.gitignore (only file touched under memory/)

# Canonical scripts — ADD if missing, NEVER overwrite (they are project-customized after init):
scripts/ci.sh, scripts/release.sh, scripts/claude-loop.sh
                         ← if the project has none, copy from temp clone templates/scripts/ and
                           tell the user to fill in the {{...}} command placeholders. If they exist,
                           leave them — the project tuned them.

# Smart merge (settings.json — add, never remove):
.claude/settings.json    ← merge the "hooks" key from templates/hooks/hooks.json (add new entries);
                           add "statusLine" only if the project has none;
                           union "permissions.allow" — add every template entry the project lacks,
                           never remove existing ones
```

**Preferences and project notes** are handled in step 5f — they need their own pass (mirror + migration + compliance), not a one-line rule here.

**Never touch** (project-specific files):
- `CLAUDE.md` — **except** the plugin-owned workflow sections, refreshed in step 5c; the title, description, `## Architecture`, and any project-authored sections are never modified
- `.claude/project-notes/` — the project's own standing rules; only ever **added to** (step 5f migration), never edited or removed
- `CONTRIBUTING.md`
- `docs/` (exception: `docs/workflow/decisions.md` is reconciled in step 5b — its **Current** values are re-applied, and newly added settings appended; existing tuned values are preserved, not reset)
- `.claude/memory/` — **except** `.claude/memory/.gitignore` (plugin-owned runtime-pattern list, refreshed in step 5); the state files themselves (decisions.md, context-*, settings.md, …) are never touched
- `.claude/workflow-source.json` (updated separately in step 6)
- Any other keys in `.claude/settings.json` (env, etc.) — and within `permissions`, preserve everything the project set; the only change permitted is **adding** any of the template's `permissions.allow` entries that the project is missing (union, never remove)
- Any project source files

For the hooks merge: read the `hooks` key of the current `.claude/settings.json`, read the new `templates/hooks/hooks.json`, add any new hook entries that don't exist yet. Do not remove entries the project added.

### 5b. Re-apply Workflow Decisions (reconcile after overwrite)

Mirroring `.claude/skills/` in step 5 reset any settings the user tuned via `/workflow-settings` whose live value lives inside a skill (e.g. `release-runner`). Most settings now live in project docs (`quality.md`, `lifecycle.md`, `release.md`, `deploy.md`, `.claude/memory/decisions.md`) which are preserved — but replay the record to be safe. `docs/workflow/decisions.md` is the record of chosen values:

1. Read `docs/workflow/decisions.md`. If it doesn't exist, skip this step (older project — offer to create it from the template).
2. For each setting whose **Current** value differs from the plugin default now sitting in its **Live in** skill file, re-apply the **Current** value to that live location (the same edit `/workflow-settings` performs). Doc-based settings (`quality.md`, `release.md`, `.claude/memory/decisions.md`) are project files and were never overwritten — leave them.
3. If the update **added new settings** to the template, append those new entries (with their defaults) to `docs/workflow/decisions.md` so the record stays complete. If it **changed a setting's format**, note the change for the user.
4. Bump `Last updated:` in `docs/workflow/decisions.md` to today.

Report how many tuned settings were re-applied so the user can confirm nothing was lost.

### 5c. Reconcile Workflow Guidance in CLAUDE.md

The project's root `CLAUDE.md` is **never overwritten** (it holds project-specific content: title, description, architecture summary, custom conventions). But the template also carries **workflow-owned sections** that describe how the *plugin* behaves — and those go stale when the plugin updates. These sections are plugin-owned, not project-specific:

> `## Quick Reference` · `## Models` · `## Agents — delegate proactively` · `## Skills — invoke proactively` · `## Scope — build the whole ticket` · `## Merging` · `## GitHub via `gh`` · `## Documentation policy` · `## Asking the user` · `## Session Behavior` · `## Memory`

(These changed in 2.x — old projects may still have `## Model & Effort Routing`, `## Multi-Task Sessions`, `## Context Management`. Those are now **retired**: remove them, and insert the new sections in template order.)

Reconcile them without disturbing the rest:

1. Read the new `{UPDATE_DIR}/templates/CLAUDE.md.template` and the project's current `CLAUDE.md`.
2. For each workflow-owned section: if the project's differs from the template's (ignoring `{{PLACEHOLDER}}` fills), **replace just that section** (match a top-level `## ` heading at column 0; replace to the next such heading — ignoring any `##` inside a fenced code block). Insert sections that are **absent** in template order; **delete** retired sections listed above.
3. **Never touch** anything else — `# {title}`, the intro, `## Architecture`, and any project-authored sections. (The standing-guidance pointer near Architecture is plugin-owned prose and may be refreshed; the project's own rules live in the separately-protected `.claude/project-notes/`.) If a workflow-owned section was renamed/heavily customized, don't silently overwrite: note it and show the new version for a hand-merge.
4. If `CLAUDE.md` changed, stage it in step 7's commit.

So skills/agents mirror wholesale, decisions replay their tuned values, and CLAUDE.md's workflow sections refresh — the update reaches existing projects, not just new ones.

### 5d. Reconcile Railway Watch Paths (if deployed on Railway)

`railway.json` lives at the repo root (not under `.claude/`), so step 5 never touches it. If the project deploys on Railway (a `railway.json`/`railway.toml` exists, or a Railway CI step is present):

1. If **no** `railway.json`/`railway.toml` exists but the project deploys on Railway: offer to add one from `{UPDATE_DIR}/templates/configs/railway.json` so docs/spec commits stop triggering redeploys.
2. If `railway.json` exists **without** `build.watchPatterns`: offer to add the template's `watchPatterns` (merge into `build`, preserve other keys).
3. If it exists **with** `watchPatterns`: never overwrite them (the project may have tuned exceptions for content it serves at runtime). If the template's default list has gained new entries since, show the diff and let the user decide.

Report any change (or offer) so the user knows the watch-path config was checked.

### 5e. Offer to compact project-authored workflow content (crossing v2.11.1)

v2.11.1 compacted the plugin's always-loaded instructions — the `CLAUDE.md` workflow sections + the agent/skill descriptions — tightening prose to direct instructions and moving on-demand detail out, without dropping a single behavioral trigger. Steps 5/5c already applied that to the **plugin-owned** files. But content the **project itself added or adapted** still carries the old, longer style: project-authored `## ` sections in `CLAUDE.md`, any skills or agents this project added locally (not shipped by the plugin), and its own files under `.claude/project-notes/`.

**Only when the recorded version is < 2.11.1** (this is a one-time migration — skip it on later updates): **offer** to apply the same compaction to that project-owned content. If the user agrees, for each such file:
- tighten prose to direct, on-the-point instructions — no filler, no restated rationale;
- move detail that's only needed on demand into the file that loads it then (a skill body, a `docs/` page, a preference file) and leave a pointer where it was;
- **keep every behavioral trigger, rule, and "when to use" keyword** — this is a wording pass, never a scope or behavior cut.

Do this **with confirmation and per file**, showing before/after — it edits project-owned content the update otherwise never touches. If the user declines, skip silently. Don't re-touch plugin-owned files (already compacted).

### 5f. Refresh Workflow Preferences, Split Out Project Notes, Check Compliance

Workflow preferences are **plugin-owned** and refresh wholesale; anything project-specific lives in `.claude/project-notes/`, which this step only ever adds to.

**a) Migrate, if the project predates the split** (no `.claude/project-notes/` yet). One-time, and it must run before the refresh in (b) overwrites anything:

1. Create `.claude/project-notes/` from `{UPDATE_DIR}/templates/project-notes/` (`README.md`, `INDEX.md.template`→`INDEX.md`; skip the example if the project already has real notes to move).
2. Classify every file in `.claude/guidelines/`. **A "library file" is one whose name appears as a row in `{UPDATE_DIR}/templates/guidelines/LIBRARY.md`** — `README.md`, `INDEX.md` and `LIBRARY.md` itself are infrastructure, not library files, and are never migrated.
   - **`README.md` / `INDEX.md`** → leave them; (b) refreshes both.
   - **`example.md`** → if it still looks like the shipped example (its first line says it's an example to delete or replace), delete it; if the user replaced its contents with something real, treat it as a user-authored file below.
   - **User-authored file** (not in LIBRARY.md) → **move** it to `.claude/project-notes/`, and move its `INDEX.md` row along, repointing the path to `.claude/project-notes/<name>.md`.
   - **Library file, unmodified** → leave it; (b) refreshes it.
   - **Library file, locally modified** → **conflict, ask**: show the diff and offer (i) take the new plugin version and keep the local edit as a project note, (ii) take the new version and drop the edit, (iii) keep the local file as a project note and don't install the library version. Never decide this silently — a local edit here was deliberate, and after this migration edits in `.claude/guidelines/` are overwritten without warning, so this is the one chance to rescue it.
3. To tell modified from unmodified, compare against the version the project came from: `git -C {UPDATE_DIR} show v{current}:templates/guidelines/<name>.md` (the clone is shallow — `git -C {UPDATE_DIR} fetch --unshallow --tags` first if that fails). If the old version can't be retrieved at all, fall back to comparing against the **new** version and ask about every file that differs — that over-asks on files upstream simply changed, which is the safe direction.
4. Report what moved.

**b) Refresh the installed preferences** (every update):
- For each library file **already present** in `.claude/guidelines/`: overwrite it from `{UPDATE_DIR}/templates/guidelines/` — no diff, no asking. This is the whole point of the split, and it's how a fixed preference reaches an existing project.
- Refresh `README.md`, and **regenerate** the `INDEX.md` rows for installed library files from `{UPDATE_DIR}/templates/guidelines/LIBRARY.md` (triggers change too).
- For a library file **not present**: offer it only if it is **newly shipped** — added to `LIBRARY.md` between `v{current}` and `{target}` (`git -C {UPDATE_DIR} show v{current}:templates/guidelines/LIBRARY.md` and diff the table). Anything that already existed at the project's current version was considered at init/onboard time and declined or not matched; re-offering it every update is exactly the recurring question this design exists to kill. Of the newly-shipped ones, check `LIBRARY.md`'s "install when" against what the project actually is (its stack, deploy target, whether it has a UI, AI features, background work) and offer only genuine matches: "This version adds `changelog.md`, which fits this project — install? [yes / no]". No new library files, or none matching → say nothing.
- If `.claude/guidelines/` is missing entirely (project predates preferences), there is no prior decision to respect: create it and offer the full matching set.

**c) Check compliance and draft the gaps** (after the refresh, so it checks against current rules):
For every preference now installed, check whether the project actually satisfies its **required** items — the baseline in `app-baseline.md` (logging, in-app changelog, update mechanism, Claude-testable live instance), `web-app-pwa.md`'s version display / update control / access gate, `logging.md`'s adjustable levels, and so on. For each real gap, create a backlog draft in `docs/specs/backlog/` naming the preference it comes from, and list them in the report. Don't fix anything here and don't block the update — the drafts are the deliverable, the user decides when to pull them in. A gap that doesn't apply to this project is dropped with a stated reason instead of drafted.

Keep this proportionate: an update that changed no preference bodies has nothing to re-check — compare the preference files between the old and new version first and only check what actually changed, plus anything newly installed.

### 6. Update Version Record
Write updated `.claude/workflow-source.json`:
```json
{ "repo": "{repo_url}", "version": "{new_version}", "installed": "{today}" }
```

### 7. Clean Up and Commit
```
rm -rf {UPDATE_DIR}
git add .claude/agents/ .claude/skills/ .claude/hooks/ .claude/memory/.gitignore .claude/guidelines/ .claude/project-notes/ .claude/settings.json .claude/workflow-source.json docs/specs/backlog/ docs/workflow/decisions.md CLAUDE.md
git commit -m "chore: update claude-workflow to {new_version}"
```

### 8. Report
Print:
```
Updated claude-workflow: {old_version} → {new_version}
Updated: agents/, skills/, hooks/ (merged), settings.json permissions (unioned)
CLAUDE.md: {K} workflow section(s) refreshed{, L flagged for manual merge} · project content preserved
Preferences: {P} refreshed{, Q newly installed}{, R conflict(s) resolved}
{If migrated: "Project notes: {S} project-owned file(s) moved to .claude/project-notes/"}
{If gaps found: "Compliance: {T} backlog draft(s) created for unmet preference requirements — {ids}"}
Decisions: {N} tuned setting(s) re-applied from docs/workflow/decisions.md{, M new setting(s) added}
{If the v2.11.1 boundary was crossed: "Compaction: {offered / applied to P file(s) / declined} for project-authored workflow content"}

{If breaking changes: "Review migration notes above and update your project files as needed."}
```

### Error Handling
- Network unavailable: print the repo URL and ask user to clone manually, then specify the path
- Invalid version tag: list available tags and ask user to choose
- Git conflicts in hooks: show the diff and ask user how to resolve
