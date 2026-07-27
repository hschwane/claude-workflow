---
name: workflow-settings
description: View or change a workflow setting — testing scope, branching model, version source, deploy target, GitHub integration, CI-on-Claude, release runner. Values live in the workflow-settings block of CLAUDE.md; this skill knows what each one means and what it is allowed to be.
argument-hint: "[setting] [value]"
disable-model-invocation: true
---

# Workflow Settings

The seven knobs that change how the workflow behaves in this project. The **values** live in the `workflow-settings` block of the root `CLAUDE.md`, so they are always in context. The **meanings and allowed values** live here, so they cost nothing until someone changes one.

## Usage
```
/workflow-settings                        # show all current values
/workflow-settings testing-scope          # show one, with its options
/workflow-settings branching git-flow     # change one
```

## The settings

| Key | Values | What it changes |
|---|---|---|
| `testing-scope` | `unit` · `unit+integration` · `unit+integration+e2e` | How deep `/plan` specs tests and `/implement` writes them. A ticket may narrow within it, never beyond it. `code-style.md` describes what each level covers |
| `branching` | `main-only` · `git-flow` | `main-only`: features merge into `main`, `/release` tags there. `git-flow`: features merge into `develop`, `/release` gates there, merges `develop → master` and tags, so `master`'s tip is always the latest release |
| `version-source` | a path — `package.json` · `pyproject.toml` · `Cargo.toml` · `CMakeLists.txt` · `VERSION` | Where `/release` reads and writes the version number |
| `deploy` | `railway` · `vercel` · `aws` · `self-hosted` · `manual` · `none` | What `release.sh` deploys to, and which guideline applies. Details in `docs/dev/deploy.md` |
| `github` | `yes` · `no` | Whether GitHub features are used at all — issues, PRs, Actions. `no` means a local-only repo |
| `ci-on-claude` | `no` · `yes` | `no` (default): Claude's commits carry `[skip ci]`, because the identical gate just ran locally. `yes`: CI runs on them too — worth it for a cross-platform library, where the matrix tests something a local run cannot |
| `release-runner` | `local` · `ci` | `local` (default): `/release` runs `release.sh` here. `ci`: it dispatches the release workflow instead, for a project that can only publish from Actions |

## Instructions

### No argument — show everything

Read the `workflow-settings` block from `CLAUDE.md` and print each key with its current value and a one-line meaning from the table above. Flag any key that is missing (an update should have added it) or unrecognised (left over from an older version).

### One argument — show one setting

Print the current value, the allowed values, and what changing it would affect.

### Two arguments — change a setting

1. **Validate.** An unknown key or a value outside the list is rejected with the allowed set. `version-source` is validated by checking the file exists.
2. **Say what it will affect**, then apply it — edit only that line inside the `workflow-settings` block, leaving the rest of `CLAUDE.md` untouched.
3. **Follow through on the consequences.** The value alone is rarely the whole change:
   - `branching` → if switching to `git-flow` and `develop` does not exist, offer to create it from the integration branch and set it as the default branch.
   - `deploy` → offer to install the matching guideline (`.claude/guidelines/`, per `LIBRARY.md`) and to fill in `docs/dev/deploy.md`.
   - `ci-on-claude: yes` → the CI workflow must not be a required status check while it is `no`; if the project made it required, say so now.
   - `release-runner: ci` → the release workflow must be `workflow_dispatch`-only, or the tag `/release` pushes will double-publish.
   - `testing-scope` widened → existing specs were written against the narrower scope; new tickets get the new depth, old ones are not retro-fitted unless asked.
4. **Record it.** Append a dated line to `.claude/memory/decisions.md` — what changed, from what to what, and why — and add the topic to that file's index line. A settings change is a decision, and six months later the reason is the part nobody remembers.

### Never

Do not put the values anywhere else. There was once a `docs/workflow/decisions.md` that recorded them while the live values sat in four other files; keeping the two in sync needed a dedicated step in `/workflow-update`, and a value living inside a skill body was reset by every update. The block in `CLAUDE.md` is the only copy.
