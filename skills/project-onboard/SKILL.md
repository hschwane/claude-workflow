---
name: project-onboard
description: Analyze an existing project and install the claude-workflow infrastructure without disrupting existing code
disable-model-invocation: true
---

# Project Onboard

Analyzes an existing project and installs the claude-workflow infrastructure without disrupting existing code. Sets up `.claude/`, memory files, workflow docs, and GitHub configuration.

## Usage
```
/project-onboard
```

## Instructions

### 0. Check Prerequisites
- Verify `git`, `gh` (GitHub CLI) are available (**required** — the workflow is git/GitHub based). If `gh` is not authenticated, run `gh auth status` and prompt the user to `gh auth login` if needed.
- Check runtimes used by the quality gates and warn (do not block) if missing:
  - `node --version` and `npx --version` — needed for the JS/TS gates (`eslint`, `prettier`, `tsc`)
  - `python --version` (fall back to `python3 --version`, or `py --version` on Windows) — needed for the Python gates (`ruff`, `mypy`)
- These are only relevant for the language detected in step 1. If the runtime for the project's primary language is missing, print a clear warning (e.g. "⚠ python not found — Python lint/type-check gates in /commit will be skipped until it's installed") and continue. A Rust/C++/other project that needs neither is fine.

### 1. Analyze Existing Project

Two-stage exploration — an overview first, then targeted depth:

**a) Overview (breadth).** Get the lay of the land cheaply before drilling in.
- **Small/medium repo:** a single `code-explorer` call covers overview + structure in one pass — use the prompt below directly and skip to step 2.
- **Large/complex repo (many packages, a big monorepo, unfamiliar sprawl):** fan out a few `text-scout` subagents in parallel from here (the main session) — each on a slice, e.g. one on the manifests + top-level layout, one on `tests/` + CI config, one on `docs/` + README. Each returns a compact **sourced** digest. Collate those into the overview. (Scouts can't spawn each other — you drive the fan-out; see the exploration note in `CLAUDE.md`.)

**b) Depth.** Once the overview shows where the interesting parts are, invoke `code-explorer` to *understand* them — the architecture, the main flows, the conventions to preserve — producing the structured report. For a small repo this is the only call; for a large one it's aimed by the scout overview instead of reading blind.

`code-explorer` prompt:

> Analyze this codebase and produce a concise report covering:
> 1. Primary language(s) and tech stack
> 2. Project type (web API, frontend, CLI, library, etc.)
> 3. Existing test setup (framework, coverage, structure)
> 4. Existing CI/CD (what's in .github/workflows/ if anything)
> 5. Directory structure (src/, tests/, docs/, etc.)
> 6. Existing documentation (README, docs/, etc.)
> 7. Git history summary (how many commits, recent activity)
> Read: package.json / pyproject.toml / Cargo.toml / CMakeLists.txt and top-level structure.
> Output a structured summary, max 400 words.

### 2. Present Findings and Ask Configuration Questions
Show the analysis summary to the user.

Ask (in chat — plain message, wait for the reply):
1. **Confirm tech stack** — "I detected {stack}. Is this correct?"
2. **GitHub** — "Does this project use GitHub? [yes/no]"
3. **Existing tests** — "I found {test info}. Should the workflow integrate with them? [yes / no, set up fresh]"
4. **Docs format** — "For workflow documentation, use: [markdown files (default) / MkDocs HTML]"
5. **Test scope** — "What test levels should the workflow use for this project? [Unit only / Unit + Integration / Unit + Integration + E2E]" — pre-select based on the detected test setup from step 1.

### 3. Install Workflow Infrastructure

The mechanical install is the same one `/project-init` does, so **it is not duplicated here** — this skill owns only what is specific to an existing codebase: merging its `CLAUDE.md`, making its real commands into a working gate, and reconciling its existing CI. Everything else is delegated, because a second hand-written copy of the install is a second copy that drifts, and only one of them gets tested.

#### 3a. Delegate the mechanical install

Invoke the `project-scaffolder` agent with `MODE: onboard` (see that agent's **Onboard mode** section — in short: never overwrite anything that exists, skip what the project already provides, install the rest). Pass the same decisions block `/project-init` step 5b uses, filled from the step 1 analysis and the step 2 answers, plus:

```
MODE: onboard
EXISTING: {what the analysis found — manifest, configs, test dir name, CI, docs}
```

It installs `.claude/` (agents, skills, hooks, `settings.json`, guidelines, memory files **with `{{PROJECT_NAME}}` filled**, `local-settings.md` in the literal `key: value` form the hooks grep for), `docs/specs/` **with `spec.md.template`** and a `.gitkeep` in each subdirectory, `docs/dev/`, `docs/VISION.md`, `.prettierignore`, `CONTRIBUTING.md`, the three `scripts/`, and `workflow-source.json`.

Three of those are easy to think of as optional and are not: **`.prettierignore`** (the ~40 markdown files just installed under `.claude/` are not prettier-formatted, so a project whose format check covers the repo now fails it), **`docs/specs/spec.md.template`** (`/draft` and `/plan` refuse to invent frontmatter without it, so the first command your own report recommends would fail), and **`docs/VISION.md`** (`/ship` reads it, and the `CLAUDE.md` you are about to install points at it).

Review its report. Then handle what it deliberately left to you, below.

#### 3b. Merge the root `CLAUDE.md`

This is the file an onboarded repo is most likely to already have, hand-written and load-bearing.

- **None exists:** write it from `templates/CLAUDE.md.template`, filling the `identity` block from the analysis and `workflow-settings` from the step 2 answers.
- **One exists:** do **not** overwrite it. Take the template as the base and sort the project's content by what it *is*:
  - a description, layout or stack → the `identity` block
  - a standing **rule** ("never use an ORM", "all money is integer cents") → a dated entry in `.claude/memory/decisions.md`, and a code-level one also into `src/CLAUDE.md`
  - an operational procedure (deploy, rollback, restart) → `docs/dev/deploy.md`, verbatim
  - a known trap → `.claude/memory/gotchas.md`

  Show the mapping and the result before writing, and **name every piece and its destination in the step 6 report**. Nothing may be dropped for want of a home.

  **Moving a rule out of `CLAUDE.md` changes when it fires.** It was on every turn; `decisions.md` is read at `/plan`, `src/CLAUDE.md` only when work touches `src/`. For most rules that is the right trade. For a **safety, privacy or legal** constraint ("never log booking payloads — they contain customer names") it is not: offer to keep a one-line version in the `identity` block as well, and say in the report that its always-loaded status was at stake.

**Do not rewrite `.claude/memory/decisions.md` after this.** It now holds the project's own house rules. Anything further — the tech-stack summary, observed patterns — is *appended* as one more dated entry.

Record the project's actual test directory name (`test/`, `tests/`, `spec/`) as a decision: the plugin-owned `CLAUDE.md` names `tests/CLAUDE.md` generically and cannot be corrected per project.

#### 3c. Make the gate real — the part that actually takes judgment

`scripts/ci.sh` is installed but unfilled. Fill each `check` line with **this project's own commands**, taken from its `package.json` scripts / `Makefile` / `pyproject.toml` / `Cargo.toml`. Use the names that exist here (`npm run fmt`, not `npm run format:check`) and go through the package manager, never a bare binary — `eslint`/`prettier`/`tsc`/`vitest` are not on `PATH` in CI.

Then `bash -n scripts/ci.sh` and run `scripts/ci.sh fast`. Three things go wrong on a real codebase, and each needs a decision rather than a shrug:

- **No command exists for a stage** (common: no `typecheck` script). Add one to the project's manifest rather than inlining a bare binary, and say you did. If the stage genuinely does not apply, delete its line — deleting them all still parses, and the script's own check counter then reports an empty gate honestly.
- **An existing command fails.** That is a pre-existing break which the gate has just made load-bearing. Show the failure, propose the smallest fix, and get agreement before editing `package.json` or dependencies. Do not quietly work around it.
- **A missing lockfile.** If CI uses `npm ci` / `uv sync --locked` / `cargo --locked` and no lockfile is committed, generate and commit it — CI fails outright without one.

**`✓ passed — 0 check(s)` is not a pass**, and neither is a stage whose command is `:` or `echo`.

**Do not reach step 5 with a red gate.** If it cannot be made green, stop: write the reason into `.claude/memory/tech-debt.md` and report `Onboarding incomplete — gate red` instead of the step 6 success block. Everything downstream (`/commit`, `/verify`, `/ship`, `/release`) is built on this script passing.

Fill `scripts/release.sh` the same way. Its healthcheck must be a real command; only the deploy step may be a no-op.

**Reconcile `testing-scope` with reality.** If the step 2 answer names a level the project has no directory or runner for, either scaffold it now or narrow the setting — never record a scope the gate does not enforce.

#### 3d. Reconcile the existing CI

If `.github/workflows/` already has CI, **do not leave it alone.** The `CLAUDE.md` you just installed asserts that the GitHub workflows call `scripts/ci.sh` — two independent definitions of "does this pass" make that false in an auto-loaded file, and the drift is invisible until something red merges.

Diff its steps against `ci.sh`, show the user the difference, and offer to replace the check steps with `- run: bash scripts/ci.sh full`, keeping the project's own triggers, matrix and any deploy/publish jobs (`templates/github/ci-{lang}.yml` is the shape to aim at). If the user declines, record the divergence in `.claude/memory/tech-debt.md` and say so in the report.

If there is no CI at all, offer `templates/github/ci-{language}.yml`.

#### 3e. Guidelines and the baseline gap check

**Install matching guidelines:** consult `templates/guidelines/LIBRARY.md` and, from the codebase analysis, detect which fit and offer to install them (copy the file + add its INDEX row from LIBRARY.md). Detection hints: a map library (Leaflet/MapLibre/Mapbox) → `maps`; a charting library or hand-rolled SVG/canvas charts → `plots-graphs`; a Telegram lib (grammY/telegraf/python-telegram-bot) → `telegram-bots`; a web app with a PWA manifest / service worker → `web-app-pwa`; Railway → `railway`; a backend/service with domain/application/infrastructure layering or non-trivial business logic → `service-architecture`; a custom logging setup worth standardizing → `logging`; cron/scheduled jobs, retry logic, or a long-running process → `background-jobs`; any app bigger than a small script/tool → `app-baseline` (plus `changelog`, `ui-frontend` and `ai-integration` where they fit). Skip any the user declines.

**Check the developer-utility baseline and draft tickets for what's missing.** For anything bigger than a small script, check what `app-baseline.md` requires against what the project actually has — structured logging with adjustable levels, version visibility, an update mechanism, an in-app changelog, a way for Claude to smoke-test a live instance, and an access gate / API token auth where applicable. For each gap, create a backlog draft in `docs/specs/backlog/` (from `spec.md.template`) and tell the user it's there. These are debugging and development infrastructure, so they're worth doing before the next feature — say that, but don't block onboarding on them. A gap the user judges irrelevant gets dropped with a stated reason, not silently.

#### 3f. Railway (if deployed there)

If the project already deploys on Railway (a `railway.json`/`railway.toml` at the repo root, a Railway CI step, or the user confirms it):
- **Install the Railway guideline** — `templates/guidelines/railway.md` → `.claude/guidelines/railway.md` plus its INDEX row: `| Railway deploy, railway.json, deployment/hosting | .claude/guidelines/railway.md |`.
- **Watch paths** — so the workflow's constant docs/spec commits don't trigger redeploys:
  - No `railway.json`/`railway.toml`: offer `templates/configs/railway.json` at the repo root.
  - One exists without `build.watchPatterns`: offer to add the array, merging into the existing `build` object.
  - It already has them: leave them — a deliberate choice; just mention the docs/spec-commit rationale.
- Set `deploy: railway` in `workflow-settings` and record platform settings, health check and required secrets in `docs/dev/deploy.md`. If the app serves markdown/docs/tests content at runtime, drop the matching `!` line from `railway.json` and note the exception.

#### 3g. Other root files

- **`README.md`:** never overwrite one that exists — offer to append a short "Development" section linking to `CONTRIBUTING.md`. Create it from `templates/README.md.template` only if absent.
- **`.env.example`:** `docs/dev/setup.md` tells the reader to `cp .env.example .env`. If the project uses a `.env` and has none, generate one from the variables the analysis found (keys only, no values). If it uses no `.env` at all, delete that section from `setup.md` rather than shipping a `cp` of a file that isn't there.

The skills, agents and hooks just installed under `.claude/` are picked up at **session start**, so they are not live in this session. Don't try to invoke one yet; the report in step 6 tells the user to restart.

### 4. GitHub Setup (if applicable)
Only run this step if the `github` setting is `yes` **and `git remote -v` resolves a GitHub remote.** Onboarding a local repo that will get its remote later is a common case for this skill, and `gh label create` fails outright with "no git remotes found".

- Create labels: `gh label create feature --force --color 0075ca` etc. (feature, bug, backlog, ready, in-progress, done — `--force` because defaults like `bug` already exist)
- Create `.github/ISSUE_TEMPLATE/feature.md` and `bug.md`

With `github: yes` but no remote yet: create the issue templates, skip the labels, and tell the user to re-run the `gh label create` block once the remote exists.

### 5. Commit
```
git add -A
git status --short          # read it — every line must be something you meant to do
git commit -m "chore: install claude-workflow infrastructure"
```

**`git add -A`, not a list.** An explicit list is a trap here: between them, this skill and the scaffolder also create `src/CLAUDE.md`, the test directory's `CLAUDE.md`, `.prettierignore`, a lockfile, and whatever manifest or config edit step 3c needed to make the gate green. A list written once is always missing the newest of those. Account for every line of `git status --short` before committing; `/project-onboard` must not end on a dirty tree.

### 6. Report

Print this **only when the gate is green** (step 3c). Otherwise report `Onboarding incomplete — gate red`, name the failing stage and why, and point at the `tech-debt.md` entry. A success banner over a red gate is the one outcome that makes everything downstream unsafe.

```
Onboarding complete ✓

Installed:
  .claude/ (agents, skills, hooks, memory, guidelines)
  docs/dev/ (code-style, setup, architecture, deploy) · docs/VISION.md
  docs/specs/ (backlog, ready, completed + spec.md.template)
  scripts/ (ci.sh, release.sh, claude-loop.sh) · .prettierignore
  {CLAUDE.md / CONTRIBUTING.md / README section / CI workflow — as created}

Gate: ci.sh fast exit {0} — {N} check(s)   ·   clean clone: exit {0}
Existing CLAUDE.md content moved to: {file → what went there, per item}
CI reconciliation: {workflow now calls ci.sh | divergence recorded in tech-debt.md}

Next steps:

  /draft feature "title"   to add first items manually
  /workflow-update         to update to latest version later

→ Restart your Claude Code session now.
  Hooks, status line, and all skills are fully active only after a fresh
  session start. Close this session and reopen it in the project directory.
```
