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

**a) Copy from claude-workflow plugin:**
Create `.claude/` directory with:
```
.claude/
├── settings.json          ← from templates/hooks/hooks.json (merge `hooks`/`statusLine`/`permissions` keys if settings.json exists — including adding a hook EVENT TYPE the project lacks, e.g. `UserPromptSubmit`, not just entries under existing ones; keep an existing statusLine; union `permissions.allow` — add any template entries that are absent, never remove existing ones)
├── hooks/
│   ├── auto-format.sh     ← parses stdin JSON, formats by language
│   ├── protect-files.sh   ← blocks edits to .env, lock files, etc.
│   ├── completeness-check.sh  ← Stop hook: keeps unsupervised work going
│   ├── session-start.sh   ← shows in-progress work / auto-resume directive
│   ├── auto-resume-guard.sh  ← UserPromptSubmit hook: arms the recovery heartbeat when auto_resume is on (cloud)
│   ├── usage-guard.sh     ← 90% usage pause for unsupervised (where usage is readable)
│   └── statusline.sh      ← status line + usage cache for the guard
├── agents/                ← copy all agent .md files
├── skills/                ← copy all skill directories (each as {name}/SKILL.md), incl. /auto-resume
├── workflow-source.json
└── memory/
    ├── decisions.md
    ├── gotchas.md
    ├── tech-debt.md
    └── .gitignore      ← from templates/memory/.gitignore
```

Write `.claude/workflow-source.json`. Read the `repository` and `version` fields from **this plugin's own `.claude-plugin/plugin.json`** (in the plugin root — the directory this skill was loaded from). Do not invent the URL; if it cannot be found, leave `repo` empty and note it in the report.
```json
{ "repo": "{repository from plugin.json}", "version": "{version from plugin.json}", "installed": "{today}" }
```

Make hook scripts executable: `chmod +x .claude/hooks/*.sh`

**Preferences folder:** create `.claude/preferences/` and copy `templates/preferences/{README.md, INDEX.md.template→INDEX.md, example.md.template→example.md}`. Ensure the root `CLAUDE.md` has the one-line **Preferences** pointer (from `templates/CLAUDE.md.template`) so `INDEX.md` is discoverable for ad-hoc work.

**Install matching library preferences:** consult `templates/preferences/LIBRARY.md` and, from the codebase analysis, detect which library preferences fit and offer to install them (copy the file + add its INDEX row from LIBRARY.md). Detection hints: a map library (Leaflet/MapLibre/Mapbox) → `maps`; a charting library or hand-rolled SVG/canvas charts → `plots-graphs`; a Telegram lib (grammY/telegraf/python-telegram-bot) → `telegram-bots`; a web app with a PWA manifest / service worker → `web-app-pwa`; Railway → `railway` (also covered by step e2 below); a backend/service with a domain/application/infrastructure-style layering or non-trivial business logic → `service-architecture`; a custom logging setup worth standardizing → `logging`; cron/scheduled jobs, retry logic, or a long-running process → `background-jobs`. Skip any the user declines; skip all if none match.

**Canonical scripts (the parity anchor — `/commit`, `/verify`, `/release` and CI all call these):**
- Copy `templates/scripts/ci.sh` → `scripts/ci.sh` and **fill the `{{...}}` placeholders** with this project's *existing* commands (detect from package.json scripts / Makefile / pyproject / Cargo — reuse what the project already uses for format/lint/typecheck/test/build). `fast` = format-check + lint + typecheck + unit; `full` = + integration/e2e + build.
- Copy `templates/scripts/release.sh` → `scripts/release.sh` and fill in the project's build/publish/deploy steps.
- Copy `templates/scripts/claude-loop.sh` → `scripts/claude-loop.sh`.
- `chmod +x scripts/*.sh`
- If the project already has an equivalent script, point `ci.sh`/`release.sh` at it (or skip and note it) rather than duplicating.

**b) Create workflow documentation** (from plugin templates/):
```
docs/workflow/
├── README.md         ← templates/workflow/README.md.template (fill `{{WORKFLOW_REPO}}` from this plugin's plugin.json `repository`)
├── lifecycle.md      ← templates/workflow/lifecycle.md.template (fill `{{BRANCHING_MODEL}}` — main-only unless git-flow detected)
├── conventions.md    ← templates/workflow/conventions.md.template
├── quality.md        ← templates/workflow/quality.md.template (fill `{{TESTING_SCOPE}}` with the test scope confirmed in step 2)
├── release.md        ← templates/workflow/release.md.template (fill `{{BRANCHING_MODEL}}`; /release and decisions.md reference this file)
└── decisions.md      ← templates/workflow/decisions.md.template (fill `{{TODAY}}`, `{{TESTING_SCOPE}}`, `{{BRANCHING_MODEL}}` (main-only unless git-flow detected), `{{GITHUB_INTEGRATION}}` = yes/no from step 2, `{{DEPLOY_TARGET}}` = detected/asked deploy target, `{{CI_ON_CLAUDE}}` = `no` (or `yes` for a cross-platform library), `{{RELEASE_RUNNER}}` = `local`). The record of all tunable workflow settings; changeable later via `/workflow-decisions`.
docs/dev/
├── setup.md          ← templates/dev/setup.md.template
└── style-guide.md    ← templates/dev/style-guide.md.template
```

If `docs/` already exists, only create files that are missing — never overwrite existing docs.

**c) Set up specs directory:**
```
docs/specs/
├── backlog/    ← (empty)
├── ready/      ← (empty)
└── completed/  ← (empty)
```

**d) Memory initialization:**
Write initial `.claude/memory/decisions.md`:
```markdown
# Architecture Decisions

## Tech Stack
{tech stack from analysis}
Added: {today}

## Existing Patterns
{key patterns observed from analysis}

## Integrations
- GitHub integration: {yes if user confirmed GitHub in step 2, else no}
```

(Do NOT create `context.md` — that name is a gitignored runtime note. Put any project overview worth keeping into `.claude/memory/decisions.md` (tracked); runtime state lives in the repo.)

Copy `templates/memory/.gitignore` → `.claude/memory/.gitignore` (prevents runtime state files from being committed to git).

**e) Language-specific CI (if missing or user wants to add):**
Check `.github/workflows/` — if no CI exists, offer to create it.
Copy the matching `templates/github/ci-{language}.yml` as `.github/workflows/ci.yml`.

**e2) Railway deployment (if deployed on Railway):**
If the project already deploys on Railway (a `railway.json`/`railway.toml` at the repo root, a Railway CI step, or the user confirms it):
- **Install the Railway preference** — copy `templates/preferences/railway.md` → `.claude/preferences/railway.md` and add its row to `.claude/preferences/INDEX.md`: `| Railway deploy, railway.json, deployment/hosting | .claude/preferences/railway.md |`. This carries the standing details (scale-to-zero, EU region, URL = project name, watch-path exclusions, and the Railway-specifics-behind-an-interface portability rule) so `/plan` picks them up when a ticket touches deployment.
- **Watch paths** — ensure `build.watchPatterns` are set so the workflow's constant docs/spec commits don't trigger redeploys:
  - If **no** `railway.json`/`railway.toml` exists: offer to copy `templates/configs/railway.json` → repo root `railway.json` (watches everything except `docs/`, `tests/`, `.claude/`, `.github/`, and markdown).
  - If one **already exists** with no `build.watchPatterns`: offer to add the `watchPatterns` array (merge into the existing `build` object; don't clobber other keys).
  - If it already has `watchPatterns`: leave them — the project has made a deliberate choice; just mention the docs/spec-commit rationale in case they want to exclude those paths.
Record the chosen target in `docs/workflow/deploy.md` (the details live in the preference, not duplicated there). If the app serves markdown/docs/tests content at runtime, drop the matching `!` line from `railway.json` and note the exception.

**f) Subdirectory CLAUDE.md files (if src/ and tests/ exist):**
Create `src/CLAUDE.md` with brief code convention note (user can expand).
Create `tests/CLAUDE.md` with testing pattern note.

**g) CONTRIBUTING.md (if not present):**
Create from `templates/CONTRIBUTING.md.template` (fill `{{WORKFLOW_REPO}}` and `{{PROJECT_NAME}}`).

**g2) README.md (if not present):**
Create root `README.md` from `templates/README.md.template`, filled with the detected project name, description, and tech stack from the analysis. **Never overwrite an existing README** — if one exists, only offer to append a short "Development" section linking to `docs/workflow/README.md`.

**h) CLAUDE.md (if not present):**
Create root `CLAUDE.md` from template, filled with detected tech stack and architecture summary.
If CLAUDE.md already exists: offer to add the workflow commands table to it.

Run `/reload-skills` so Claude Code picks up the newly installed skills and agents from `.claude/` without requiring a session restart. After the reload, all workflow commands (`/draft`, `/plan`, `/implement`, etc.) are immediately available.

### 4. GitHub Setup (if applicable)
Only run this step if the user answered **yes** to the GitHub question in step 2 (i.e., `decisions.md` will contain `GitHub integration: yes`):
- Create labels: `gh label create feature --force --color 0075ca` etc. (feature, bug, backlog, ready, in-progress, done — `--force` because defaults like `bug` already exist)
- Create `.github/ISSUE_TEMPLATE/feature.md` and `bug.md`

### 5. Commit
```
git add .claude/ docs/workflow/ docs/specs/ CLAUDE.md CONTRIBUTING.md .github/
git commit -m "chore: install claude-workflow infrastructure"
```

### 6. Report
```
Onboarding complete ✓

Installed:
  .claude/ (agents, skills, hooks, memory)
  docs/workflow/ (lifecycle, conventions, quality docs)
  docs/specs/ (backlog, ready, completed directories)
  {CLAUDE.md / CONTRIBUTING.md / CI workflow — if created}

Next steps:

  /draft feature "title"   to add first items manually
  /workflow-update         to update to latest version later

→ Restart your Claude Code session now.
  Hooks, status line, and all skills are fully active only after a fresh
  session start. Close this session and reopen it in the project directory.
```
