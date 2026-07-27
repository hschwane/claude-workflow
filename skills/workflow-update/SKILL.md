---
name: workflow-update
description: Update this project's claude-workflow files to a newer plugin version, driven by the delivery manifest — plugin files are replaced, project content is preserved, and anything the two share is merged with you watching.
argument-hint: "[version tag, e.g. v3.1.0]"
disable-model-invocation: true
---

# Workflow Update

Pulls a newer plugin version into this project. Three rules decide everything:

1. **Only files the plugin actually changed** between the installed and the target version are touched at all.
2. **The manifest decides ownership** — anything not listed in it belongs to the project and is never touched.
3. **Nothing is lost silently.** Where the two sides overlap, you see a diff before anything is written.

## Usage
```
/workflow-update
/workflow-update v3.1.0
```

## Instructions

### 1. Read the current state

Read `.claude/workflow-source.json` for `repo` and `version`. If it is missing, this project was not set up by `/project-init` or `/project-onboard` — say so and offer to create it.

Require a clean working tree (`git status`). The update writes across many files and lands in one commit; starting dirty makes a partial failure impossible to unpick. Stop and say so if it isn't clean.

### 2. Fetch the target version

Clone into a temp directory — detect the shell rather than assuming:
- Bash / Git Bash: `UPDATE_DIR="${TMPDIR:-/tmp}/claude-workflow-update"`
- PowerShell: `$UPDATE_DIR = "$env:TEMP\claude-workflow-update"`

Delete a leftover directory from a previous run, then `git clone {repo_url} {UPDATE_DIR}`. **Do not use `--depth 1`**: the whole update needs the *installed* version's files as a merge base, so the history must be there. Target = the argument, or `git -C {UPDATE_DIR} tag --sort=-version:refname | head -1`.

Throughout, `OLD` means `git -C {UPDATE_DIR} show v{current}:<path>` and `NEW` means the file at that path in the clone. If `v{current}` cannot be resolved (a hand-installed project, a deleted tag), say so and treat every plugin file as changed — that is the safe direction, because it surfaces everything rather than skipping silently.

### 3. Show what changed

`git -C {UPDATE_DIR} log v{current}..{target} --oneline`. Highlight `BREAKING`, `[BREAKING]` or a `!` marker prominently.

Then compute the **actual work list**: for every path in `{UPDATE_DIR}/.claude-plugin/delivery.json`, diff OLD against NEW. A path where they are identical is **not touched** and is not mentioned again. Report the count: "14 of 37 delivered paths changed."

### 4. Confirm

Show the work list grouped by manifest class, then ask: "Update from {current} to {target}? [yes / choose another version / cancel]". If there are breaking changes, ask about those separately.

### 5. Apply, class by class

Read `{UPDATE_DIR}/.claude-plugin/delivery.json`. It gives every delivered path a class, and **a path that is not listed belongs to the project — never touch it.** If the new version delivers a path the manifest does not list, stop and report it: that is a plugin bug, and guessing is how a project's file gets overwritten.

**Before creating any file that did not exist before, check whether the project already has one at that path.** If it does, do not overwrite — treat it as a `mixed` case and merge with confirmation.

#### `plugin` — replace, but mirror by manifest

For a directory (`.claude/skills/`, `.claude/agents/`, `.claude/guidelines/`, `.claude/hooks/`):
- **Refresh** the files the new manifest lists, where OLD ≠ NEW.
- **Delete** files that a *previous* manifest listed and this one no longer does. Use the manifest's `removedIn{N}` list plus the old version's manifest if present; on the 2.x→3.0 step, the removals are in `removedIn3`.
- **Leave everything else alone.** A hook, skill or agent the project added itself is not yours to delete. This is the whole reason mirroring is manifest-driven rather than delete-then-copy.

For a single file (`docs/dev/code-style.md`, `scripts/claude-loop.sh`), replace it when it changed.

**Files with marker blocks** (`CLAUDE.md`, `CONTRIBUTING.md`) are plugin files too, but their project blocks survive:
1. Parse the project's copy for `project-specific: start: <id>` / `end: <id>`. **A marker counts only when it is the entire line** after trimming — the same text inside a sentence, inline code or a fenced block is prose, and every shipped `CLAUDE.md` contains exactly that as documentation.
2. **Unpaired marker → stop and ask.** Never guess where a block ends; guessing deletes the rest of the file.
3. **Duplicate id → stop and ask.** The id is what makes re-insertion unambiguous.
4. Take NEW as the base and fill each of its blocks with the project's content for the same id.
5. A rescued block whose id NEW no longer has: append it at the end under `## Unplaced project content`, and **say so in the report**. Never drop it.
6. Before replacing, diff the project's *plugin* regions against OLD. If the project edited one, that edit is about to be lost — show it and ask, rather than replacing quietly.

**The `workflow-settings` block is merged, not replaced:** keys from NEW, values from the project. A newly shipped setting appears with its default, a retired one disappears, a tuned value stays. Report added and removed keys.

#### `mixed` — merge by hand, every time

`scripts/ci.sh`, `scripts/release.sh`, the two workflow YAMLs, `.claude/settings.json`. Markers cannot work here: the plugin's scaffolding and the project's content are interleaved, or the format carries no comments.

Only when OLD ≠ NEW: perform a three-way merge — **base** OLD, **ours** the project's file, **theirs** NEW. Carry the plugin's change into the project's file while keeping everything the project put there. Then **show the resulting diff and ask before writing.**

For `scripts/ci.sh` and `release.sh` specifically: the project's real commands live in the body. A merge that leaves a stage empty produces a script that **exits 0 with nothing to run** — a gate that passes on nothing, silently. After merging, verify each stage still contains a real command and not just a comment; if one is empty, stop and ask.

`.claude/settings.json` has a fixed rule and needs no diff: add hook entries from `templates/hooks/hooks.json` that are missing, add `statusLine` only if absent, union `permissions.allow`, and never remove anything.

#### `project` — suggest, never rewrite

`README.md`, `docs/**`, `src/CLAUDE.md`, `tests/CLAUDE.md`, the configs, `.claude/memory/*`. These were handed to the project at creation.

When the upstream **template** changed, do not touch the file. Instead, describe what changed and suggest how it might apply here — as a note in the report, for the user to act on or ignore. Most updates will have nothing to say.

### 5b. One-time migration, v2.x → v3.0

Run only when the recorded version is below 3.0.0. **Order matters** — later steps delete what earlier steps read.

1. **Collect the settings first, before anything is deleted.** Read the *Current* column of `docs/workflow/decisions.md`. If it is missing, fall back to the live locations: `docs/workflow/quality.md` (testing scope), `lifecycle.md` (branching), `release.md` (version source), `deploy.md` (deploy target), the `/release` skill (`release-runner`), `.claude/memory/decisions.md` (GitHub integration). Anything still unresolved: **ask, do not guess.** Defaults if the user has no opinion: `testing-scope: unit+integration`, `branching: main-only`, `github: yes`, `ci-on-claude: no`, `release-runner: local`, `deploy: none`, `version-source` from whichever manifest the project actually has.
2. **`.claude/preferences/` → `.claude/guidelines/`.** Rename. Overwrite the library files from the new version and regenerate their INDEX rows from `LIBRARY.md`. A file the project wrote itself (not in `LIBRARY.md`) is not a guideline: show it and ask whether it becomes an entry in `decisions.md` (a rule) or `gotchas.md` (a fact). Never delete it.
3. **`.claude/project-notes/` → memory.** For each note, show it and ask which file it belongs in. These were trigger-indexed and will now be read during `/plan` instead — say that, because it changes when they fire.
4. **`CLAUDE.md`.** Collect the title, description, architecture summary, stack and any project-authored `##` sections into the `identity` block of the new template. Diff the plugin sections against OLD first and surface anything the project edited (step 5). Fill the `workflow-settings` block from step 1.
5. **`CONTRIBUTING.md`.** Diff against OLD. Anything the project added goes into the `contributing` block; the rest is replaced. The v2 file contradicts the current rules — it claims merges only happen via `/pr` and names four agents deleted in 2.x — so replacing it is the point.
6. **`docs/workflow/`.** Move `deploy.md` → `docs/dev/deploy.md` and append the Required Secrets section from `release.md`. Then delete `README.md`, `lifecycle.md`, `conventions.md`, `quality.md`, `release.md` **and `decisions.md`**. Before deleting each, diff it against OLD: if the project edited it, that content is project-owned — show it and ask where it should go.
7. **`docs/dev/style-guide.md`.** Install `code-style.md`, then diff the old style guide against OLD; anything the project added is offered for `decisions.md` or `src/CLAUDE.md`. Then delete it.
8. **`docs/dev/adr/`.** Retired. Each ADR is real project content: offer to move it into `docs/dev/` as a normal document, with a one-line entry in `decisions.md` pointing at it. Never delete an ADR silently.
9. **`.claude/memory/settings.md` → `local-settings.md`.** Rename the file, and make sure the new `.gitignore` is in place first — the old name is what it ignores, and this file holds the recovery-trigger id.
10. **`src/CLAUDE.md` and `tests/CLAUDE.md`.** The v3 versions are much smaller because the rules moved to `code-style.md`. These are `project` files: leave them, and tell the user what moved so they can trim their own copies.

### 6. Check for dead references

The update renamed and removed paths. Grep the **project-owned** files — `README.md`, `docs/**`, `CONTRIBUTING.md`'s project block, `src/CLAUDE.md`, `tests/CLAUDE.md`, `mkdocs.yml` — for every path this update removed or moved. Offer a targeted correction for each hit. Do not rewrite the file wholesale; these are the project's.

### 7. Review before committing

Verify, and report each check:
- Every `project-specific` marker is paired, and no id appears twice.
- No rescued block was dropped — the count going in equals the count coming out, plus anything listed under `## Unplaced project content`.
- The `workflow-settings` block has every key the new version ships and no stale ones.
- `scripts/ci.sh` has a real command in every stage.
- No dead references remain, or the remaining ones were explicitly declined.
- Hooks are executable (`chmod +x .claude/hooks/*.sh`) and pass `bash -n`.

If a check fails, fix it or stop — never commit a half-migrated project.

### 8. Record and commit

```
{ "repo": "{repo_url}", "version": "{new_version}", "installed": "{today}" }
```

```
git add -A
git commit -m "chore: update claude-workflow to {new_version}"
```

One commit, so the whole update can be reverted as a unit.

### 9. Report

```
Updated claude-workflow: {old} → {new}
Touched {N} of {M} delivered paths ({M-N} unchanged upstream, untouched here)

plugin    {n} refreshed{, k removed}{, j project-added files left alone}
blocks    {n} project block(s) carried over{, k unplaced}
mixed     {n} merged with confirmation
project   {n} suggestion(s) — see below
settings  {n} carried over{, k added}{, j retired}

{Migration, if v2 → v3: what moved where, and what the user was asked about}
{Suggestions for project files, if any}
{Dead references fixed / declined}
```

### Error handling

- **Network unavailable:** print the repo URL, ask the user to clone manually, then take the path.
- **Unknown version tag:** list the available tags.
- **A merge you cannot resolve confidently:** stop and hand the user the three versions (base, theirs, ours). A wrong merge in `ci.sh` is a silently passing gate — stopping is cheap by comparison.
