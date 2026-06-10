---
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
If this file doesn't exist: print an error explaining this project wasn't set up with `/project-init` and offer to create it manually.

### 2. Fetch Latest Version
Clone the workflow repo into a temp directory (cross-platform):
```bash
# Unix/Mac/Git Bash:
TMPDIR="${TMPDIR:-/tmp}/claude-workflow-update"
# Windows PowerShell:
# $TMPDIR = "$env:TEMP\claude-workflow-update"

git clone --depth 1 {repo_url} "$TMPDIR"
```
Get the latest version tag:
```
cd "$TMPDIR" && git tag --sort=-version:refname | head -1
```

If a target version was specified as an argument: use that instead of latest.

### 3. Show What Changed
- Read `/tmp/claude-workflow-update/CHANGELOG.md`
- Extract entries between current version and target version
- Display them to the user

Check for breaking changes: if the changelog contains `BREAKING` or `[BREAKING]`, highlight them prominently.

### 4. Confirm
Ask the user (via AskUserQuestion):
- "Update from {current} to {target}? [yes / choose different version / cancel]"

If breaking changes exist, show them explicitly and ask separately: "This update has breaking changes. Review them above. Continue?"

### 5. Apply Update
Copy only the **system files** from the temp clone to this project's `.claude/`:
```
# Overwrite (system files — always updated):
.claude/agents/          ← copy all from temp clone
.claude/skills/          ← copy all from temp clone

# Smart merge (hooks — add new hooks, never remove existing ones):
.claude/hooks/           ← merge, not overwrite
```

**Never touch** (project-specific files):
- `CLAUDE.md`
- `CONTRIBUTING.md`
- `docs/`
- `.claude/memory/`
- `.claude/workflow-source.json` (updated separately in step 6)
- Any project source files

For the hooks merge: read current hooks.json, read new hooks.json, add any new hook entries that don't exist yet. Do not remove entries.

### 6. Update Version Record
Write updated `.claude/workflow-source.json`:
```json
{ "repo": "{repo_url}", "version": "{new_version}", "installed": "{today}" }
```

### 7. Clean Up and Commit
```
rm -rf "$TMPDIR"
git add .claude/agents/ .claude/skills/ .claude/hooks/ .claude/workflow-source.json
git commit -m "chore: update claude-workflow to {new_version}"
```

### 8. Report
Print:
```
Updated claude-workflow: {old_version} → {new_version}
Updated: agents/, skills/, hooks/ (merged)
Preserved: CLAUDE.md, docs/, memory/

{If breaking changes: "Review migration notes above and update your project files as needed."}
```

### Error Handling
- Network unavailable: print the repo URL and ask user to clone manually, then specify the path
- Invalid version tag: list available tags and ask user to choose
- Git conflicts in hooks: show the diff and ask user how to resolve
