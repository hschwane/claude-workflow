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

Read `.claude/workflow-source.json` for `repo`, `version` and (if present) `variants`. `repo` is the bare `owner/repo`; older files may hold a full URL, so normalize either form to `https://github.com/{owner}/{repo}` for the clone and write the bare form back in step 8. If the file is missing, this project was not set up by `/project-init` or `/project-onboard` — say so and offer to create it.

Require a clean working tree (`git status`). The update writes across many files and lands in one commit; starting dirty makes a partial failure impossible to unpick. Stop and say so if it isn't clean.

### 2. Fetch the target version

Clone into a temp directory — detect the shell rather than assuming:
- Bash / Git Bash: `UPDATE_DIR="${TMPDIR:-/tmp}/claude-workflow-update"`
- PowerShell: `$UPDATE_DIR = "$env:TEMP\claude-workflow-update"`

Delete a leftover directory from a previous run, then `git clone {repo_url} {UPDATE_DIR}`. The argument may also name a **local clone, a fork or an alternate remote** (`/workflow-update ../claude-workflow`) — clone from there instead, and read the target version from its `.claude-plugin/plugin.json`. **Do not use `--depth 1`**: the whole update needs the *installed* version's files as a merge base, so the history must be there. Target = the argument, or `git -C {UPDATE_DIR} tag --sort=-version:refname | head -1`. The argument may also be a branch or `HEAD` (installing an unreleased version); in that case read the target's version from `{UPDATE_DIR}/.claude-plugin/plugin.json` rather than the tag name, since every later step compares versions, not refs.

Throughout, a manifest entry's **`source`** field is where the file lives in the plugin repo — the `path` is where it lives in a project, and the two differ (`.claude/skills/` ← `skills/`, `CLAUDE.md` ← `templates/CLAUDE.md.template`). So `OLD` means `git -C {UPDATE_DIR} show v{current}:{entry.source}` and `NEW` means `{UPDATE_DIR}/{entry.source}`. Comparing against the project path instead returns the plugin's own file and the whole work list comes out wrong.

**`OLD` must resolve, or you stop.** Two things break it:
- **The plugin renamed its own directory.** `.claude/guidelines/` came from `templates/preferences/` before 3.0.0, so `git show v2.15.0:templates/guidelines/railway.md` fails outright. The entry's **`sourceBefore`** map gives the earlier path — use it when the installed version is **strictly below** the version it lists. At or above it, the current `source` is correct — reading `sourceBefore` there would fail `git show` and abort every later update on that path.
- **The tag is gone** (a hand-installed project, a deleted tag). Say so and treat every plugin file as changed: that surfaces everything instead of skipping silently.

A failed `git show` is **never** "no OLD, so this is a new file, safe to overwrite." That reading is what silently destroys a project's edit to a shipped file. If OLD does not resolve for a path the project already has, stop and say which path.

### 3. Show what changed

`git -C {UPDATE_DIR} log v{current}..{target} --oneline`. Highlight `BREAKING`, `[BREAKING]` or a `!` marker prominently.

Then compute the **actual work list**: for every path in `{UPDATE_DIR}/.claude-plugin/delivery.json`, diff OLD against NEW. A path where they are identical is **not touched** and is not mentioned again. Report **both** counts: "6 of 39 delivered entries changed (11 files)". M counts the manifest entries that have a `source`, **minus** the other-language `project` paths the previous paragraph already keeps off the work list — otherwise two operators produce two different denominators for the same repo. Give the file count too — a directory entry like `.claude/skills/` can hide a dozen files, and the entry count alone reads as a much smaller change than it is. **Count only files that actually land in a project:** `templates/guidelines/LIBRARY.md` and `INDEX.md.template` change upstream but are plugin-side and never delivered, so a changed `.claude/guidelines/` entry is worth fewer files than its diff suggests.

Three rules make that computable:
- **"Unchanged upstream" only excuses a path the project already has.** A delivered path the project is *missing* goes on the work list whatever the diff says. `templates/hooks/hooks.json` is often byte-identical across versions — drop it here and `.claude/settings.json` is never installed, leaving every refreshed hook present but unwired, and nothing later notices.
  **This applies to `plugin` paths and to the three `mixed` ones the workflow cannot run without** (`.claude/settings.json`, `scripts/ci.sh`, `scripts/release.sh`). A missing **`project`**-class path is not a gap — a TypeScript repo has no `Cargo.toml`, and a project that never released has no `docs/changelog/`. Leave those off the work list entirely rather than reporting nine other-language manifests on every update forever — **except the handful §5a deliberately creates** because the `CLAUDE.md` and `CONTRIBUTING.md` this update installs index them (`docs/dev/setup.md`, `docs/VISION.md`, `docs/specs/*`, `docs/user/README.md`, `.env.example`). Those belong on the work list as *to create*, not as missing manifests; read §5a's `project` section before you finalise the list, or a fresh always-loaded index will point at four paths that do not exist.

  **Being on the work list is not the same as being installed.** Everything else missing is **reported, not created** — installing `.github/workflows/` into a project with `github: no` is not a fix, it is a surprise. And a missing path whose `source` is a directory has no file to detect the variant from: ask which applies, or omit it.
- **An entry with no `source` is never diffed.** It is project state the plugin does not author (`local-settings.md`, `context-*.md`, `docs/user/`, `.env.example`, `docs/changelog/`, `docs/specs/`). Take the list from the manifest rather than from memory — entries gain a `source` between versions.
- **A directory `source` under a narrower `path` is a *filtered* mirror** — only the members matching `path` are delivered. `templates/hooks/` holds `hooks.json`, which belongs to `.claude/settings.json`, not to `.claude/hooks/*.sh`; `templates/github/` holds eight CI and release YAMLs that are not `.github/ISSUE_TEMPLATE/`. A naive whole-directory copy installs all of them in the wrong place.
- **A directory `source` under a single-file `path`** means the plugin ships variants and the project holds one. Read `variants` from `.claude/workflow-source.json` (e.g. `{"ci": "ci-typescript.yml", "release": "release-npm.yml", "gitignore": "typescript.gitignore"}`). If it is absent — a project installed before variants were recorded — identify the member by comparing the project's file byte-for-byte against each candidate **at the installed tag**, then **write the result into `workflow-source.json` in step 8** and diff against that one. If the project has no such file at all, omit the key rather than guessing, and say so in the report. Never diff a file against a whole directory.

### 4. Confirm

Show the work list grouped by manifest class, then ask: "Update from {current} to {target}? [yes / choose another version / cancel]". If there are breaking changes, ask about those separately.

### 5. Apply

**If the recorded version is below 3.0.0, run §5b first and come back.** The v2 layout has no marker blocks at all, so treating `CLAUDE.md` as a plugin file here would take the new template as its base, find no blocks to carry over, and write out the bare template — the project's title, architecture and its own sections gone, with none of the guards in this section firing. `CLAUDE.md`, `CONTRIBUTING.md`, `.claude/preferences/` and `docs/` are handled in §5b, not here.

### 5a. Class by class

Read `{UPDATE_DIR}/.claude-plugin/delivery.json`. It gives every delivered path a class, and **a path that is not listed belongs to the project — never touch it.** If the new version delivers a path the manifest does not list, stop and report it: that is a plugin bug, and guessing is how a project's file gets overwritten.

**Before creating any file that did not exist before, check whether the project already has one at that path.** If it does, do not overwrite — treat it as a `mixed` case and merge with confirmation.

#### `plugin` — replace, but mirror by manifest

For a directory (`.claude/skills/`, `.claude/agents/`, `.claude/guidelines/`, `.claude/hooks/`):
- **Refresh** the files the new manifest lists, where OLD ≠ NEW.
- **Delete** what the plugin removed. `removedIn{N}` covers whole paths retired at a major (`removedIn3` for the 2.x→3.0 step), but a directory entry like `.claude/skills/` is not enumerated, so a skill retired in a patch release is invisible to it. Compute those directly: `git -C {UPDATE_DIR} diff --name-status v{current}..{target} -- {entry.source}` and delete the project's copy of every `D` path. Without this a retired skill lingers in every project forever and `/plan` keeps finding it.
- **Leave everything else alone.** A hook, skill or agent the project added itself is not yours to delete. This is the whole reason mirroring is manifest-driven rather than delete-then-copy.

For a single file (`docs/dev/code-style.md`, `scripts/claude-loop.sh`), replace it when it changed.

**Install what the project does not have.** A `plugin`-class path the new manifest lists and the project lacks is *installed*, not skipped — **unless it configures a tool the project does not use.** `.prettierignore` in a repo with no formatter is noise: report it instead.  — "only changed files are touched" is about files that exist on both sides. That is how `docs/specs/spec.md.template` (which `/plan` reads for every ticket) reaches a project that predates it.

**Exceptions are marked by a `note` in the manifest — read the note before mirroring a directory.**

`.claude/guidelines/` is the big one, and it has three parts:
- **Install the complete library, every time.** Copy every `.md` from the new `templates/guidelines/` except `LIBRARY.md` and `INDEX.md.template` (plugin-side, never delivered). There is no offer set, no matching and no per-project selection — every project gets every guideline, so a project that grew a background job or a UI since the last update simply has the guideline already. A file the project deleted comes back; that is intended, and the way to opt out of a guideline's advice is a dated decision in `.claude/memory/decisions.md`, which this never touches.
- **Diff each against OLD before replacing it.** A project that appended its own section to a shipped guideline (a region override, a tightened limit) loses it silently otherwise, and "upstream fixed a guideline this project had tweaked" is the most ordinary event there is. Show the edit and ask where it goes: **[a]** a dated deviation in `.claude/memory/decisions.md` naming the guideline, for a *rule*; **[b]** `.claude/memory/gotchas.md`, for a *fact that cost someone time*; **[c]** discard. Never offer "leave it in the guideline" — this directory is plugin-owned, so the next update deletes it again. Only then overwrite. `README.md` in that directory has the same exposure.
- **`README.md` is refreshed like any plugin file.** It is not a guideline and is not in `LIBRARY.md`; left alone it keeps describing the directory under its pre-3.0 name.
- **`INDEX.md` is copied verbatim from `INDEX.md.template`**, like any other plugin file. It ships with a row for every guideline in the library and is identical in every project, so there is nothing to generate. **Do not rebuild it row-by-row from the directory** — that was necessary when the installed set varied per project and is now just a way to lose rows.
- **One exception, and it is the only thing here that is per-project:** rows the project added for **user-global** guidelines (from `~/.claude/guidelines/`, installed at init/onboard) are not in the template and would be dropped by a verbatim copy. Before overwriting, note any row whose file is not in the plugin's library, and re-append it afterwards. Their `.md` files are project-side and must not be deleted.

`.claude/ui/` follows its guideline: install a UI template only when the guideline referencing it is installed.

**Files with marker blocks** (`CLAUDE.md`, `CONTRIBUTING.md`) are plugin files too, but their project blocks survive:
1. Parse the project's copy for `project-specific: start: <id>` / `end: <id>`. **A marker counts only when it is the entire line** after trimming — the same text inside a sentence, inline code or a fenced block is prose, and every shipped `CLAUDE.md` contains exactly that as documentation. **Ids contain hyphens** — `ci-model` and `ci-note` alongside `identity` and `contributing` — so match `[A-Za-z0-9_-]+`; a `\w+` pattern finds no block at all for those two and silently drops them. The manifest's `blocks` list is the expected set; a block present in the file but not the list means the manifest is stale, not that the block is bogus.
2. **Unpaired marker → stop and ask.** Never guess where a block ends; guessing deletes the rest of the file.
3. **Duplicate id → stop and ask.** The id is what makes re-insertion unambiguous.
4. Take NEW as the base and fill each of its blocks with the project's content for the same id. **Substitute the template tokens as at install time** (`{{PROJECT_NAME}}`, `{{WORKFLOW_REPO}}` from `.claude/workflow-source.json`). This applies to tokens in the file's **plugin region** — `CONTRIBUTING.md`'s title and its plugin banner. A token inside a `project-specific` block is different: that block is filled from the project's own copy, so its values come from there and are never re-substituted. Filled plugin-region tokens are not project edits — exclude those lines from the step-6 diff.
4b. **Resolve the template's own authoring comments before writing, and delete them.** Two blocks ship an HTML comment addressed to *you*, listing conditional cases: `CLAUDE.md`'s `ci-model` and `CONTRIBUTING.md`'s `ci-note`. Pick the case matching `github` and whether a remote exists, write that text as the block's content, delete the comment. This is the same rule `agents/project-scaffolder.md` applies at init — without it a migrated project is permanently *worse* than a freshly created one, because once an authoring comment is inside a `project-specific` block it is project content: no later update ever refreshes or removes it. `ci-model` sits in the always-loaded root `CLAUDE.md`, so it is then read on every turn of every session, forever. **No `{{` sweep can catch this** — the comments contain no tokens — and only `ci-note`'s text happens to say "delete this comment", so following the comments themselves is not enough.
5. A rescued block whose id NEW no longer has: append it at the end under `## Unplaced project content`, and **say so in the report**. Never drop it.
6. Before replacing, diff the project's *plugin* regions against OLD. If the project edited one, that edit is about to be lost — show it and **ask where it goes**: a `project-specific` block; a dated deviation in `.claude/memory/decisions.md` if it is a rule; `.claude/memory/gotchas.md` if it is a fact that cost someone time; or discard. Do not offer "leave it in the plugin region": that region is replaced by definition, so the next update deletes it again and the user learns the marker system does not work.

**The `workflow-settings` block is merged, not replaced:** keys from NEW, values from the project. A retired key disappears, a tuned value stays, and a newly shipped setting appears with its default.

**Take that default from the `/workflow-settings` table in the target version, not from the template.** The template ships `{{TOKEN}}` placeholders, never values — writing one through puts an unsubstituted token into an always-loaded file, which §7 then hard-stops on, aborting the whole update the first time a release adds a setting.

A row that marks no default is a **plugin bug**, not a reason to stop. Do not omit the key either — a missing key breaks `/workflow-settings`'s own completeness check and leaves the project half-updated. Take the **first listed value**, write it, and name the key and the value you defaulted in the report so the user can correct it with one command. This also has to work unsupervised, where asking is not available. Report added and removed keys.

#### `mixed` — merge by hand, every time

The manifest's `mixed` entries — today `scripts/ci.sh`, `scripts/release.sh`, the two workflow YAMLs, `.github/dependabot.yml` and `.claude/settings.json`. Read the class off the manifest rather than this list, which ages. Markers cannot work here: the plugin's scaffolding and the project's content are interleaved, or the format carries no comments.

**If the project has no copy at all, install NEW and then fill or delete every stage before continuing.** A missing `scripts/ci.sh` is a missing gate, not an unchanged file. Do not install it and move on: a placeholder is an executable line, so an unfilled `ci.sh` aborts with exit 127 and §7 will not let it be committed.

For a project with a real toolchain, fill the stages from what it already uses (its `package.json` scripts, `Makefile`, `pyproject.toml`). For one with **no** toolchain at all — a scripts or docs repo — delete every stage. The script is built for that: the `full` block keeps a trailing `:` so it still parses, and the `CHECKS` guard then makes it exit 1 saying "this gate proves nothing" rather than passing on nothing. Record the gap in `.claude/memory/tech-debt.md`, and set `CI_ALLOW_EMPTY=1` in the project's CI only if the user deliberately accepts a stub gate.

Otherwise, only when OLD ≠ NEW: perform a three-way merge — **base** OLD, **ours** the project's file, **theirs** NEW. Carry the plugin's change into the project's file while keeping everything the project put there. Then **show the resulting diff and ask before writing.**

For `scripts/ci.sh` and `release.sh` specifically: the project's real commands live in the body, and NEW carries only placeholders where they go.

- **The project's body wins, always.** Take from NEW only what is genuinely plugin scaffolding — the mode dispatch, `set -euo pipefail`, the comments, a newly added stage. Never let a placeholder from NEW displace a real command; on a conflict hunk where "ours" has commands and "theirs" has `{{...}}`, keep ours verbatim.
- **After merging, grep `scripts/*.sh` for `{{` and stop if anything remains.** In v3 a placeholder is a bare command line rather than a comment, so a merged-in `{{FORMAT_CHECK}}` does not sit quietly — the gate aborts at that line with exit 127 on every run. The stage-is-not-empty check below passes it, because a token is not a comment.
- Then verify each stage still contains a real command and not just a comment; if one is empty, stop and ask. A stage that is only a comment produces a script that **exits 0 with nothing to run** — a gate that passes on nothing, silently.
- Finally run `bash -n scripts/ci.sh` and `scripts/ci.sh fast`, and confirm it executed the project's commands. This is the one merge whose result you can cheaply prove.

**A `mixed` file can carry install-time tokens too, and the scripts-only grep above will not catch them.** The CI workflow you just wrote — `.github/workflows/ci.yml` in the project, installed from `templates/github/ci-<lang>.yml` — ships `branches: {{CI_BRANCHES}}` **twice** — on the `push` trigger and on `pull_request`. (Glob the project path, not the plugin's dashed one, or you match nothing and conclude there is nothing to fill.) Fill **both**; a substitution that stops at the first match leaves a live token in the PR trigger. Substitute the **whole bracketed list** from the `workflow-settings` block before writing: `[<trunk-branch>]` under `branching: main-only`, `[<trunk-branch>, develop]` under `git-flow`. A literal `{{CI_BRANCHES}}` there is not an error anyone sees — the workflow parses, commits, and then matches no branch ever again — and dropping `develop` under git-flow kills CI on the branch every feature merges into. Silent CI death is worse than exit 127. Grep the workflow files you wrote for `{{ *[A-Z_]` and treat a hit exactly like one in a script.

`.claude/settings.json` has a fixed rule and needs no diff: add hook entries from `templates/hooks/hooks.json` that are missing, add `statusLine` only if absent, union `permissions.allow`, and never remove anything.

#### `project` — suggest, never rewrite

`README.md`, `docs/**`, `src/CLAUDE.md`, the test directory's `CLAUDE.md` (resolve the real directory — `tests/`, `test/`, `spec/`), the configs, `.claude/memory/*`. These were handed to the project at creation.

When the upstream **template** changed, do not touch the file. Instead, describe what changed and suggest how it might apply here — as a note in the report, for the user to act on or ignore. Most updates will have nothing to say.

**One thing this class does create.** The `CLAUDE.md` and `CONTRIBUTING.md` this update installs ship a "Where things live" index. A path in that index that does not exist is a broken pointer in an always-loaded file — the reader follows it, finds nothing, and stops trusting the table. So create what is missing: `docs/dev/setup.md`, `docs/VISION.md`, `docs/specs/{backlog,ready,completed}/` (a `.gitkeep` each, so a fresh clone still has them), and **`docs/user/README.md`** from `templates/dev/user-readme.md.template` — a bare `docs/user/` directory leaves the `[User guide](docs/user/README.md)` link in the README you just installed pointing at nothing. Leave unknown tokens as `_TBD_`.

**`.env.example` ships no template** — its manifest entry has no `source`, so there is nothing to copy. Write it by hand: a header comment naming the project and pointing at `docs/dev/setup.md`, plus any variable the deploy doc already names. `setup.md` tells the reader to `cp .env.example .env`, so its absence is a broken first step. List them in the report as stubs to fill. Derive the set from the two files you just installed rather than from this list — it ages with the templates.

### 5b. One-time migration, v2.x → v3.0

Run only when the recorded version is below 3.0.0. **Order matters** — later steps delete what earlier steps read, and several need a destination that does not exist yet.

**0. Create the destinations.** `.claude/memory/decisions.md`, `gotchas.md` and `tech-debt.md` are `project`-class, so §5a will never create them — but steps 2, 3, 6, 7 and 8 all move project content *into* them. For each one the project does not have, install it now from `{UPDATE_DIR}/templates/memory/<name>.md.template`, substituting `{{PROJECT_NAME}}`. Leave any that already exists untouched.

**1. Collect the settings, before anything is deleted.**

Read the *Current* column of `docs/workflow/decisions.md`. Treat a cell as **empty** when it holds `{{…}}`, `TBD`, `—`, `n/a`, **or the v2 template's own instructional filler** — an unfilled template is not an answer, and copying one forward ships a sentence of prose into a file loaded on every turn. The filler does not always look like a token: v2's version-source row ships the literal text *"set at init for this language (e.g. `package.json` version, `Cargo.toml`, `pyproject.toml`, a VERSION file)"*, which reads like an answer and is not one. A cell that lists options, hedges, or says "e.g." is filler.

For anything empty or missing, fall back to the live locations: `docs/workflow/quality.md` (testing scope), `lifecycle.md` (branching), `release.md` (version source), `deploy.md` (deploy target), the `/release` skill (`release-runner`), and for `github`, the repo itself — whether it has a `.github/` directory **or** a GitHub remote: either one alone means `yes`, neither means `no`, and if the two disagree in a way that matters to you, ask. (A repo with committed workflows and no remote yet is the common shape and is `yes`.) (`.claude/memory/decisions.md` is listed in older guidance but is created blank by step 0 on a v2 project, so it can never answer this.)

v2 wrote these as prose. Map what you find onto the v3 values:

| Setting | v2 wording | v3 value |
|---|---|---|
| `testing-scope` | "unit tests only", "no integration tests" | `unit` |
| | "unit + integration", "integration where it matters" | `unit+integration` |
| | "e2e", "end-to-end", "full pyramid" | `unit+integration+e2e` |
| `branching` | "trunk", "main only", "commit straight to main" | `main-only` |
| | "git-flow", "develop branch", "release branches" | `git-flow` |
| `trunk-branch` | no v2 equivalent — v2 hardcoded `main`/`master` in every workflow | **Ask the repo, not the docs** — resolve in the order below. Never the template default, and never `lifecycle.md`'s boilerplate. |
| `version-source` | the manifest named in `release.md` | one of the values `/workflow-settings` allows — see below |
| `deploy` | the platform named in `deploy.md` | one of the values `/workflow-settings` allows — see below |
| `github` | issues/labels mirrored | `yes` / `no` |
| `ci-on-claude` | CI runs on Claude's own pushes | `yes` / `no` |
| `release-runner` | release runs via GitHub Actions | `ci`, otherwise `local` |

**Take the allowed values from `/workflow-settings`, not from here.** That skill's table is authoritative for `deploy` (`railway` · `vercel` · `aws` · `self-hosted` · `manual` · `none`) and `version-source` (a manifest path, `VERSION`, or `none`). Map the v2 prose onto one of those; if none fits, ask. Writing a value outside the set — `docker`, a free-text platform name — puts something into an always-loaded block that `/workflow-settings` will reject the first time anyone tries to change it.

**`version-source` has a terminal branch:** a project with no manifest at all (a scripts or docs repo) has nothing to bump — set it to `none` and say so, so `/release` asks for the version instead of reading a file that isn't there. But `none` is only right when nothing is versioned: if the project has no manifest yet its release workflow publishes a package, **ask** — and say what the valid answers are: an existing file path, or `none`. `/workflow-settings` validates this by checking the file exists, so naming a manifest that has not been created yet produces a value it will later reject. Set `none` and record restoring the manifest as tech debt.

Anything still unresolved: **ask, do not guess.** Defaults if the user has no opinion: `testing-scope: unit+integration`, `branching: main-only`, `github: yes`, `ci-on-claude: no`, `release-runner: local`, `deploy: none`, `version-source` from whichever manifest the project has, else `none`. **`trunk-branch` has no default at all** — see below.

**`trunk-branch` never falls through to a default, the template's or anyone else's.** It is the one setting whose wrong value is silently destructive: §5a substitutes it into the CI workflow's push trigger and `/release` merges and tags on it. Write `main` into a repo whose trunk is `master` and CI never fires again while releases target a branch that does not exist — no error, valid YAML, dead trigger.

**Resolve it from git history, in this order. Stop at the first source that answers:**

1. **Which branch carries the release tags.** `/release` tags on the trunk, so the trunk has them and a vestigial branch has none:
   ```bash
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -v '^develop$'); do
     echo "$b: $(git tag --merged "$b" | wc -l) tag(s), $(git rev-list --count "$b") commit(s)"
   done
   ```
   **Zero tags everywhere means this source did not answer** — a project that has never released has none to carry. Fall through; do not read "0 and 0" as a tie to break on commit count.
2. **Which branch `develop` is actually merged into** — the same question asked of merge commits rather than tags:
   ```bash
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -v '^develop$'); do
     n=0
     for m in $(git log --first-parent --merges --format='%H' "$b"); do
       git merge-base --is-ancestor "$m^2" develop 2>/dev/null && n=$((n+1))
     done
     echo "$b: $n develop-merge(s)"
   done
   ```
   The branch with merges is the release target; a vestigial branch has none. This is the source that survives a repo with no tags and no remote, which is why it comes before the two that need one.
3. `git symbolic-ref --short refs/remotes/origin/HEAD` (only with a remote; it fails on a repo that has none).
4. `git branch --show-current`, **and only under `branching: main-only`**.

**Do not use `docs/workflow/lifecycle.md`.** Its trunk sentence looks like the perfect answer and is plugin boilerplate: the file ships *both* models with hardcoded names — "main-only: … tags on `main`" and "git-flow: … merges `develop → master`" — while the only project-specific line is `This project uses: **{{BRANCHING_MODEL}}**`, which v2 left as an unfilled token. Reading it therefore returns `master` for **every** git-flow project and `main` for **every** main-only one, whatever the repo actually does. That is not evidence, it is a constant that happens to be right about half the time. (If a project genuinely edited that sentence — diff it against `templates/workflow/lifecycle.md.template` at the installed tag — then it *is* evidence. Byte-identical to the template means it is not.)

Two traps behind the ordering:

- **Under `git-flow`, `git branch --show-current` is the wrong source**, which is why it is gated to `main-only`. You are almost certainly standing on `develop` — that is where the workflow leaves you and where migration work happens. `trunk-branch: develop` is not a value anything rejects: the branch exists, so the CI trigger becomes `[develop, develop]` and `/release` merges `develop → develop` and tags there while the real trunk never advances again.
- **A repo with both `main` and `master` accepts either.** GitHub creates `main` at repo creation and plenty of projects went on using `master`, leaving a branch that resolves perfectly well and means nothing. Existence is not trunk-ness — that is exactly what sources 1 and 2 discriminate and a bare `rev-parse` cannot.

**Say in the report which branch you picked and which numbered source decided it**, so a wrong pick is visible rather than merely valid. If no source answers, **ask**, naming the candidates. This is not a setting to guess at.

**Two settings are not in the v3 block and must not be lost with the file.** v2's `decisions.md` also carries `## Pause threshold (unsupervised)` and `## Auto-resume`. These are personal, so they go to `.claude/memory/local-settings.md` (step 9), not into `CLAUDE.md`. Collect them here, before step 6 deletes the file.

Record the **variants** while you are at it — which `ci-<lang>.yml`, `release-*.yml` and `<lang>.gitignore` this project was installed from. Step 8 writes them into `workflow-source.json` so the next update can diff a file against a file.

**2. `.claude/preferences/` → `.claude/guidelines/`.** Rename the directory, then — **before regenerating anything**:
- **OLD is `templates/preferences/<file>` here**, not `templates/guidelines/<file>`, which does not exist before 3.0.0 (`sourceBefore` in the manifest). Getting this wrong makes every guideline look brand-new, and the next bullet silently does nothing.
- A file that is not listed in `LIBRARY.md` **and is not `README.md` or `INDEX.md`** is project-authored, not a guideline. Show it and ask whether it becomes an entry in `decisions.md` (a rule) or `gotchas.md` (a fact); move it, then drop it from the directory. Doing this *after* regenerating the INDEX leaves it sitting there with no index row — present but unreachable.
- For each library file the project does have, **diff it against OLD before overwriting.** A project that appended its own line to a shipped guideline (a region override, a tightened limit) loses it otherwise. Show the edit and ask where it goes — normally `decisions.md` as a dated deviation naming the guideline — and only then overwrite.
- Overwrite the library files **and `README.md`** from NEW; the README is plugin-owned and still describes the directory by its old name until you do.
- Install the **whole** library from the new `templates/guidelines/`, not just the files the v2 project happened to have. A v2 project carries only the subset that matched at its init, and 3.1 does away with that: every project gets every guideline. This replaces the old "compute an offer set and ask" step entirely — there is nothing to offer, because nothing is optional.
- Copy `INDEX.md.template` → `INDEX.md` verbatim. It already lists every library guideline. A v2 project's index held only its subset, so **do not** carry the old rows forward — except any row pointing at a file that is not in the library, which is a user-global guideline and is re-appended (see §5a).

**3. `.claude/project-notes/` → memory.** `README.md` and `INDEX.md` there are plugin scaffolding, not notes — delete them without asking. For each actual note, show it and ask which file it belongs in (`decisions.md` for a rule, `gotchas.md` for a fact). These were trigger-indexed and fired on a keyword match; they will now be read during `/plan` instead — say that, because it changes when they fire. Remove the directory once every note has a home.

**4. `CLAUDE.md`.** Take the new template as the base.
- Into the `identity` block go the title, description, architecture summary and stack — **what the project *is***.
- A project-authored `##` section is identity only if it describes the project. A **standing rule** ("always use X", "never call Y directly") is not: it belongs in `decisions.md`, or in `src/CLAUDE.md` if it is code-level. **Never `docs/dev/code-style.md`** — that file is plugin-owned and carries no marker blocks, so anything put there is deleted by the next update. Ask per section instead of sweeping everything into the block — an identity block full of rules is a rule nobody reads at the moment it applies. **Name every section you moved, and where it went, in the report**; §7 checks against that list.
- **One exception.** A safety, privacy or legal constraint ("this data is never logged, not even at debug level") has to hold on *every* turn, not only during `/plan`. Moving it to `decisions.md` is a real behavior change, because ad-hoc work outside a ticket never reads that file. Offer to keep it as a one-line constraint in the `identity` block as well, and say in the report that its always-loaded status was at stake.
- Diff the plugin sections against OLD first and surface anything the project edited (§5a, step 6).
- Fill the `workflow-settings` block from step 1, **resolve the `ci-model` authoring comment and delete it exactly as §5a step 4b prescribes**, and **substitute every remaining `{{…}}`**. Step 4b is easy to miss from here: §5b owns these two files, so the §5a class walk never runs on them, and the comment carries no token for the substitution sweep to catch. This is the only pass in which it gets resolved — after this it is project content inside a marker block, in the always-loaded root file, and no later update can touch it.

**5. `CONTRIBUTING.md`.** Install NEW, substituting `{{PROJECT_NAME}}` and `{{WORKFLOW_REPO}}` — the latter is the **bare `owner/repo`**, normalized from `repo` in `.claude/workflow-source.json` *now*, not at step 8. A v2 file holds the full URL, and the template interpolates it as `https://github.com/{{WORKFLOW_REPO}}`, so passing it through produces a doubled link in the banner at the top of the file. Diff the project's copy against OLD; anything the project added goes into the `contributing` block, the rest is replaced. **Resolve the `ci-note` authoring comment and delete it, per §5a step 4b** — same reasoning as `ci-model` above. The v2 file contradicts the current rules — it claims merges only happen via `/pr` and names four agents deleted in 2.x — so replacing it is the point.

**6. `docs/workflow/`.**
- Move `deploy.md` → `docs/dev/deploy.md`. If `docs/dev/deploy.md` already exists, merge with confirmation rather than overwriting.
- Append the **Required Secrets** section from `release.md` — *unless* the moved file already has one. The two are named differently (`## Required Secrets (GitHub Actions)` in the source, `## Required GitHub Secrets` in the destination); they are the same section. If both are still unfilled templates, keep one empty table and say it needs filling. If both have content, show both and ask. Appending blind produces two conflicting secret lists, and the wrong one gets followed at 3am.
- **Substitute the tokens.** The moved file arrives with a dozen `{{...}}` in it. Fill what step 1 already knows (`{{DEPLOY_TARGET}}`, the secret names from `release.md`) and ask for the rest. An unfilled `{{ROLLBACK_PROCEDURE}}` is worse than an empty one — `CLAUDE.md` sends you here for exactly that, mid-incident.
- The v3 deploy template makes three edits beyond the `preferences`→`guidelines` rename: `## Required GitHub Secrets` → `## Required deployment secrets`, `### Automated Steps (in CI deploy.yml or release.yml)` → `### Automated steps`, and the prerequisite bullet rewritten from "GitHub Secret" to secret-or-environment-variable. Apply those to the moved file — a local release has no GitHub secrets, and the v2 headings say it does. There is nothing else to offer.
- Then delete `README.md`, `lifecycle.md`, `conventions.md`, `quality.md`, `release.md` **and `decisions.md`**, and remove the now-empty `docs/workflow/`. Before deleting each, diff it against OLD. The `removedIn3` entries carry no `source`, so resolve it by hand: OLD for `docs/workflow/<name>.md` is `templates/workflow/<name>.md.template` at the installed tag. If the project edited it, that content is project-owned — show it and ask where it should go.

**7. `docs/dev/style-guide.md`.** Install `code-style.md`, then diff the old style guide against OLD; anything the project added is offered for `decisions.md` or `src/CLAUDE.md`. Then delete it.

**8. `docs/dev/adr/`.** Retired. Each ADR is real project content: offer to move it into `docs/dev/` as a normal document, with a one-line entry in `decisions.md` pointing at it. Never delete an ADR silently. Remove the directory once it is empty — an empty `adr/` left behind reads as "ADRs still live here", and the next one gets written into it.

**9. `.claude/memory/local-settings.md`.** Install the new `.claude/memory/.gitignore` from NEW **first** — §5a has not run yet, so the project is still on the v2 gitignore, which ignores `settings.md` and not `local-settings.md`, and acting in the other order stages a file holding the recovery-trigger id for commit.

- If `.claude/memory/settings.md` exists, rename it.
- **If it does not, create `local-settings.md` anyway.** `settings.md` was gitignored in v2, so it is simply absent from any fresh clone — but the `CLAUDE.md` this update just installed tells every session the toggles live there. Seed it with exactly these three lines, adjusted to the values collected in step 1:
  ```
  unsupervised: false
  auto_resume: false
  usage_threshold: 90
  ```
  The key names are literal — `session-start.sh` and `completeness-check.sh` grep `^unsupervised:`, `auto-resume-guard.sh` greps `^auto_resume:`, `usage-guard.sh` and `statusline.sh` grep `^usage_threshold:`. A file written as `**unsupervised:** false` or `pause_threshold: 90` is silently ignored by every one of them.

**10. `src/CLAUDE.md` and the test directory's `CLAUDE.md`.** The v3 versions are much smaller because the rules moved to `code-style.md`. These are `project` files: leave them, and tell the user what moved so they can trim their own copies.

If §5b.4 routed a code-level rule into `src/CLAUDE.md`, you have now touched an auto-loaded file that may still hold `{{…}}` from its own init. Fill what you know and replace the rest with `_TBD_ (was {{TOKEN_NAME}})` — keeping the name, because four bare `_TBD_`s in an auto-loaded file tell the reader something is missing without telling them what. Never stop the migration over a token that predates it.

**11. Return to §5a** and run the class walk for everything else. `CLAUDE.md`, `CONTRIBUTING.md`, `.claude/guidelines/`, `.claude/memory/.gitignore` and `docs/dev/deploy.md` are already handled — skip **their class walk** there. §5a step 4b still applies to `CLAUDE.md` and `CONTRIBUTING.md`: it is the only place the `ci-model` and `ci-note` authoring comments are resolved, and steps 4 and 5 above are where you do it.

### 6. Check for dead references

The update renamed and removed paths. On the v2→v3 step those are at least `docs/workflow/`, `docs/dev/style-guide.md`, `docs/dev/adr/`, `.claude/preferences/` and `.claude/memory/settings.md`. Grep for every path this update removed or moved, across **both** the project-owned files (`README.md`, `docs/**`, `CONTRIBUTING.md`'s project block, `src/CLAUDE.md`, the test directory's `CLAUDE.md`, `mkdocs.yml`) **and the files this update just wrote** — a stale path shipped in a template lands in every project otherwise.

**Exclude `.claude/skills/` and `.claude/agents/`.** They describe this very migration and name the old paths on purpose; `workflow-update/SKILL.md` alone produces a dozen deliberate hits, and wading through them every run trains you to skim the ones that matter.

Offer a targeted correction for each hit **in a file the project owns**. Do not rewrite the file wholesale; these are the project's.

**A hit in a file this update just wrote from a template is not the project's to fix.** Correcting it locally is reverted at the next update, which teaches the user the marker system does not hold. Report it as an **upstream bug**, naming the template and the line, offer no local edit, and do not hold this check open on it.

### 7. Review before committing

Verify, and report each check:
- Every `project-specific` marker is paired, and no id appears twice.
- **No authoring comment survives inside a marker block.** Grep each block's contents for `<!--`. **Three blocks ship one, and they are not the same case.** For `ci-model` and `ci-note` a hit means step 4b was skipped, and it is unrecoverable by any later update — the comment is now project content in an always-loaded file. `contributing`'s comment is a *placeholder addressed to the user*, not an instruction to you: delete it if the project has content for that block, leave it if the block is empty, and say which in the report. Treating it as a defect hard-stops the update on the default state of most projects.
- **No `{{…}}` token that *this update introduced*** remains anywhere. Take the set from `git diff --name-only` against the pre-update HEAD rather than from a list, then apply two exclusions and one rule:
  - **Exclude `.claude/skills/`, `.claude/agents/` and `docs/specs/spec.md.template`.** They document the templates and carry tokens on purpose — `project-scaffolder.md` alone has dozens. Without this exclusion the check fails on every migration, forever, and an operator learns to skip it.
  - **A token that was already unfilled before this update is not this update's doing.** That covers `docs/dev/deploy.md` after the move, `src/CLAUDE.md`, `docs/dev/architecture.md`, `README.md` — any `project`-class file the update touched only to correct a reference. Fill what you know, leave the rest, list them in the report as pre-existing work, **and append one line per file to `.claude/memory/tech-debt.md`**. A report line is read once and evaporates; an auto-loaded file with a raw token is read on every turn until someone fixes it. This is what stops §6's dead-reference repair from turning into a self-inflicted stop: correcting a stale path in `README.md` must not make you responsible for tokens that have sat there since init.
  - **Inside `.github/workflows/`, `${{ … }}` is GitHub Actions expression syntax, never a template token.** `group: ci-${{ github.ref }}` and `${{ secrets.NPM_TOKEN }}` are correct code. Match `{{ *[A-Z_]` rather than `{{` there — allow the spaces, since `{{ CI_BRANCHES }}` is just as dead as the unpadded form — so the real ones — `{{CI_BRANCHES}}` in the `push` **and** `pull_request` triggers — still stop you. A check that fires on every workflow file teaches the operator to wave workflow hits through, which is exactly how a dead CI trigger ships.
  - **The hard stop is a token this update wrote.** In an always-loaded file, a script, **or a CI workflow**, no exceptions — except the `_TBD_ (was {{NAME}})` form §5b.10 mandates, which is a deliberate marker naming what is missing, not an unfilled token. A workflow earns the same treatment as a script even though nothing crashes: the failure mode is a trigger that matches no branch, so the update's own evidence — "CI is green" — becomes "CI never ran".
- No rescued block was dropped. For a v2→v3 migration the count is meaningless (a v2 project has zero blocks): verify instead that **every project-authored heading identified in §5b.4 and §5b.5 is accounted for** — inside a block, under `## Unplaced project content`, or as an entry in `decisions.md` / `gotchas.md` / `src/CLAUDE.md` named in the report. Routing a standing rule out of `CLAUDE.md` is the correct outcome, not a dropped block; what is forbidden is a heading nobody can say the fate of.
- The `workflow-settings` block has every key the new version ships and no stale ones, **and every value is one the target version's `/workflow-settings` table lists for that key** — for `version-source`, that the named file exists. Checking keys alone passes a block whose values are template defaults, which is how a wrong `trunk-branch` reaches a commit.

  **For `trunk-branch`, `git rev-parse --verify` is necessary and nowhere near sufficient** — it proves the branch exists, not that it is the trunk, and every wrong candidate exists. So also assert: it is **not** `develop` (nor any other integration branch) when `branching: git-flow`; and if the repo holds both `main` and `master`, that the one you wrote is the one carrying the release tags and the `develop` merges (§5b.1 sources 1 and 2). A vestigial `main` in a `master` repo passes a bare existence check, which makes it inert on the majority of real repos.

  **If you cannot get evidence, this check FAILS — it does not pass by default.** That is the whole difference between a backstop and a formality: a repo with no tags, no merges and no remote gives the check nothing to work with, and "unevaluable" must mean stop and ask which branch is the trunk, naming both candidates. Do **not** reach for `docs/workflow/lifecycle.md` to break the tie — §5b.6 deleted it several steps ago, and §5b.1 explains why its answer was never evidence in the first place. Name the branch and the numbered source that decided it in the report. This block is always-loaded and `/workflow-settings` will reject a bad value the first time anyone edits it.
- `.claude/settings.json` exists and its hook entries point at scripts that exist. Hooks are executable (`chmod +x .claude/hooks/*.sh`) and pass `bash -n`. Installed-but-unwired hooks are the quietest way for this update to have done nothing.
- `.claude/guidelines/` holds every `.md` in the plugin's library (count them), `INDEX.md` matches `INDEX.md.template` except for any re-appended user-global rows, and every row's file exists. A directory shorter than the library means a filter crept back in.
- `scripts/ci.sh` **and `scripts/release.sh`** pass `bash -n` and contain no `{{`; then run `scripts/ci.sh fast` and report the exit code and the check count it prints.
  **A surviving `{{…}}` in a script is always a hard stop, pre-existing or not.** This is the one place where "the update didn't cause it" is wrong: v2 placeholders were comments and v3's are executable lines, so this update converts a gate that quietly passed into one that aborts with exit 127. Fill the stage, or delete its line — deleting them all still parses, and the script's own `CHECKS` guard then reports an empty gate honestly instead of a false pass.
  **`✓ passed — 0 check(s)` is not a pass.** If the count is zero, or a stage's command is `:`/`true`/`echo`, the gate is a stub: say so in the report and record it in `tech-debt.md`. A green run that tested nothing is the failure this whole section exists to prevent.
  **Exit 1 with 0 checks is the honest outcome for a project with no toolchain**, not a failed check — the guard is doing its job. Record it in `tech-debt.md` and continue to §8; do not treat it as the "fix it or stop" case below.
- No dead references remain, or the remaining ones were explicitly declined.

If a check fails, fix it or stop — never commit a half-migrated project.

### 8. Record and commit

```json
{
  "repo": "{owner/repo}",
  "version": "{new_version}",
  "installed": "{today}",
  "variants": { "ci": "ci-typescript.yml", "release": "release-npm.yml", "gitignore": "typescript.gitignore" }
}
```

`repo` is the bare `owner/repo`, never a URL — `/workflow-update` builds the clone URL from it and `CONTRIBUTING.md` interpolates it into `https://github.com/{{WORKFLOW_REPO}}`. If the file you read at step 1 held a full URL, normalize it here. `variants` records which language/target templates this project was installed from, so the next update can diff a file against a file (§3); carry forward what was already there and add what you resolved. If nothing could be resolved — no workflow, no `.gitignore`, nothing to detect from — **omit the `variants` key entirely**; an empty object reads to the next update as "resolved to nothing" rather than "never determined".

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
