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
Ask the user (via AskUserQuestion):
- "Update from {current} to {target}? [yes / choose different version / cancel]"

If breaking changes exist, show them explicitly and ask separately: "This update has breaking changes. Review them above. Continue?"

### 5. Apply Update
Copy only the **system files** from the temp clone to this project's `.claude/`:
```
# Overwrite (system files — always updated):
.claude/agents/          ← copy all from temp clone (agents/)
.claude/skills/          ← copy all from temp clone (skills/, preserving {name}/SKILL.md structure)
.claude/hooks/*.sh       ← copy all from temp clone (templates/hooks/*.sh)

# Smart merge (hook configuration — add new entries, never remove existing ones):
.claude/settings.json    ← merge the "hooks" key from temp clone's templates/hooks/hooks.json;
                           add "statusLine" only if the project has none;
                           union "permissions.allow" — add EVERY entry from the template's
                           permissions.allow that the project is missing, never remove existing
                           allow entries (this delivers new plugin permissions on every update,
                           not just the wake tools)
```

**Never touch** (project-specific files):
- `CLAUDE.md` — **except** the plugin-owned workflow sections, refreshed in step 5c; the title, description, `## Architecture`, and any project-authored sections are never modified
- `CONTRIBUTING.md`
- `docs/` (exception: `docs/workflow/decisions.md` is reconciled in step 5b — its **Current** values are re-applied, and newly added settings appended; existing tuned values are preserved, not reset)
- `.claude/memory/`
- `.claude/workflow-source.json` (updated separately in step 6)
- Any other keys in `.claude/settings.json` (env, etc.) — and within `permissions`, preserve everything the project set; the only change permitted is **adding** any of the template's `permissions.allow` entries that the project is missing (union, never remove)
- Any project source files

For the hooks merge: read the `hooks` key of the current `.claude/settings.json`, read the new `templates/hooks/hooks.json`, add any new hook entries that don't exist yet. Do not remove entries the project added.

### 5b. Re-apply Workflow Decisions (reconcile after overwrite)

Overwriting `.claude/skills/` in step 5 replaced every skill with the plugin defaults — including any settings the user tuned via `/workflow-decisions` (refine sizing, review tier, auto-merge, …), whose live values are stored **inside** those skills. `docs/workflow/decisions.md` is a preserved project file and is the record of the chosen values, so replay it back into the fresh skills:

1. Read `docs/workflow/decisions.md`. If it doesn't exist, skip this step (older project — offer to create it from the template).
2. For each setting whose **Current** value differs from the plugin default now sitting in its **Live in** skill file, re-apply the **Current** value to that live location (the same edit `/workflow-decisions` performs). Doc-based settings (`quality.md`, `release.md`, `.claude/memory/decisions.md`) are project files and were never overwritten — leave them.
3. If the update **added new settings** to the template, append those new entries (with their defaults) to `docs/workflow/decisions.md` so the record stays complete. If it **changed a setting's format**, note the change for the user.
4. Bump `Last updated:` in `docs/workflow/decisions.md` to today.

Report how many tuned settings were re-applied so the user can confirm nothing was lost.

### 5c. Reconcile Workflow Guidance in CLAUDE.md

The project's root `CLAUDE.md` is **never overwritten** (it holds project-specific content: title, description, architecture summary, custom conventions). But the template also carries **workflow-owned sections** that describe how the *plugin* behaves — and those go stale when the plugin updates. These sections are plugin-owned, not project-specific:

> `## Quick Reference` (command table) · `## Agents — delegate proactively` · `## Skills — invoke proactively` · `## Model & Effort Routing` · `## Multi-Task Sessions` · `## Session Behavior` · `## Memory` · `## Context Management`

Reconcile them without disturbing the rest:

1. Read the new `{UPDATE_DIR}/templates/CLAUDE.md.template` and the project's current `CLAUDE.md`.
2. For each workflow-owned section above: if the project's version differs from the template's (ignoring `{{PLACEHOLDER}}` fills, which don't appear in these sections — they're project-independent), **replace just that section** in the project `CLAUDE.md` (match a top-level `## ` heading at column 0; replace from it to the next such heading). **Only real section headings count — ignore any `##` line inside a fenced code block** (e.g. the `## In Progress` example inside `## Multi-Task Sessions`), so a section is never truncated at a fenced pseudo-heading. If a section is **absent** from the project (e.g. a new `## Model & Effort Routing` on a pre-routing project), insert it in template order.
3. **Never touch** any section not in the list above — especially `# {title}`, the intro description, `## Architecture`, and any project-authored sections. When a project has renamed or heavily customized a workflow-owned section, do **not** silently overwrite it: note it in the report and show the new template version for the user to merge by hand.
4. If `CLAUDE.md` was changed, stage it in step 7's commit.

This is the CLAUDE.md analogue of step 5b: skills/agents get overwritten wholesale, decisions replay their tuned values, and the workflow-owned prose sections of CLAUDE.md refresh to the new plugin version — so a routing change (or any future guidance change) actually reaches existing projects instead of only new ones.

### 6. Update Version Record
Write updated `.claude/workflow-source.json`:
```json
{ "repo": "{repo_url}", "version": "{new_version}", "installed": "{today}" }
```

### 7. Clean Up and Commit
```
rm -rf {UPDATE_DIR}
git add .claude/agents/ .claude/skills/ .claude/hooks/ .claude/settings.json .claude/workflow-source.json docs/workflow/decisions.md CLAUDE.md
git commit -m "chore: update claude-workflow to {new_version}"
```

### 8. Report
Print:
```
Updated claude-workflow: {old_version} → {new_version}
Updated: agents/, skills/, hooks/ (merged), settings.json permissions (unioned)
CLAUDE.md: {K} workflow section(s) refreshed{, L flagged for manual merge} · project content preserved
Decisions: {N} tuned setting(s) re-applied from docs/workflow/decisions.md{, M new setting(s) added}

{If breaking changes: "Review migration notes above and update your project files as needed."}
```

### Error Handling
- Network unavailable: print the repo URL and ask user to clone manually, then specify the path
- Invalid version tag: list available tags and ask user to choose
- Git conflicts in hooks: show the diff and ask user how to resolve
