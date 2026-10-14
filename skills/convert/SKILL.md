---
name: convert
description: Convert a project that carries any older version of this plugin (claude-workflow v1.0 – v3.x) to wf v4 — detect the version, read what that release installed, remove the untouched plugin copies, carry the project's real decisions over, and prove the gate still passes. Use when a project still has the old .claude/skills, guidelines, memory files or workflow-settings block.
argument-hint: "[path]"
disable-model-invocation: true
---

# Convert

You tailor this procedure to the project; there is no fixed table of old files. The old plugin's
history is the reference: the repository `hschwane/claude-workflow`, one tag per release
(`v1.0.0` … `v3.3.0`). Clone it once into a scratch directory (`git clone --filter=blob:none`) or
read it with `gh api`.

## 1. Detect the version
- `.claude/workflow-source.json` (v3) names the version; a settings block or a `CHANGELOG`-style
  note may too.
- Otherwise find it: list the project's plugin-shaped files (`.claude/skills/*`, `.claude/agents/*`,
  `.claude/hooks/*`, `.claude/guidelines/` or older guideline folders, `.claude/memory/`,
  `docs/workflow/`, `scripts/ci.sh` and siblings) and compare them with candidate tags — the tag
  whose files match most closely is the installed version. Say how sure you are.

## 2. Learn what that release put where
Read the tag: its skills and templates, its scaffolder or init/onboard instructions, and from v3 on
its `.claude-plugin/delivery.json`, which classifies every delivered path as `plugin`, `project` or
`mixed` and lists retired paths. Build the list of paths that version installs into a project.

## 3. Classify every footprint file
- **Identical** to the release's version → untouched plugin copy: remove.
- **Same path, different content** → edited by the project: show the diff against the release's
  version and decide with the user; never delete silently.
- **Project work** → keep: filled `scripts/ci.sh` / `release.sh` / `healthcheck.sh`, specs,
  `docs/design/`, documents the project wrote under `docs/`.
- **Decisions to carry over** → see step 5.

## 4. Report first, change nothing
Every file with its fate — remove / keep / convert / ask — and why, plus the version and how sure
you are. Wait for the user's go.

## 5. Convert, on a branch
- **Remove** the untouched copies: old skills, agents, hooks **and their entries in
  `.claude/settings.json`**, guideline copies, templates, `claude-loop.sh`, `dev.sh` (after
  `/run-skill-generator` has recorded the run recipe, for a runnable app), `gate-status.sh`,
  `criteria-check.sh`, `deploy-reference.sh` unless the project relies on it, `workflow-source.json`,
  the old settings skill's files.
- **Carry decisions into their v4 homes** — only what is a real, still-valid project decision:
  - the old settings block (any version's spelling) → the `<!-- wf:settings -->` block
    (`${CLAUDE_PLUGIN_ROOT}/skills/setup/decisions.md` names the keys);
  - `decisions.md`, `gotchas.md`, `tech-debt.md` → a short `CLAUDE.md` line for each rule the user
    wants kept, an issue for real open debt if the project uses GitHub; everything else is dropped
    (list what was dropped in the report);
  - the project's own parts of `CLAUDE.md` stay; the old workflow prose goes; cut toward ~60–200
    lines, proposing rather than deleting hand-written content;
  - specs in `docs/specs/{backlog,ready,in-progress,completed}/` → `docs/specs/` with `status:` in
    the frontmatter (`spec-mode: files`), or leave them where they are if the user prefers.
- **Scripts:** `ci.sh` / `release.sh` / `healthcheck.sh` stay as filled; remove calls to deleted
  helpers (`gate-status.sh`) and `.claude/memory/` paths so they still run.
- **Install** `wf` at project scope: the marketplace and plugin in `.claude/settings.json`
  (`extraKnownMarketplaces` with `hschwane/claude-workflow`, `enabledPlugins` with `wf@hschwane`).

## 6. Prove it
Run `scripts/ci.sh full` **before** converting and **after**: both green, the same number of tests
executed. A difference is a defect of the conversion — fix it before committing.
Commit (`chore: convert to wf v4`), and report every removed, converted and kept file.
