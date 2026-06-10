---
name: project-init
description: Create a new project from scratch with full claude-workflow infrastructure — vision, architecture, configs, CI, hooks, and initial backlog
argument-hint: "[project-name]"
disable-model-invocation: true
---

# Project Init

Creates a new software project from scratch with the full claude-workflow infrastructure. Guides through product vision, architecture, tech stack, initial backlog, CI, release, and deploy setup.

## Usage
```
/project-init
/project-init "My Project Name"
```

## Instructions

### 0. Check Prerequisites
- Verify `git`, `gh` (GitHub CLI) are available
- If `gh` is not authenticated: `gh auth status` — if not logged in, prompt user to run `gh auth login`
- Ask (AskUserQuestion): "Create a GitHub repository? [yes — public / yes — private / no, local only]"

### 1. Project Basics
Ask the user (AskUserQuestion):
1. **Project name** (if not in args)
2. **Short description** (one sentence)
3. **Project type**: Web API / Web Frontend / CLI tool / Library / Desktop App / Other
4. **Primary language**: TypeScript (recommended) / Python / Rust / C++ / Other

If user selects JavaScript instead of TypeScript: note "TypeScript is recommended for better AI-assistance and type safety. Use TypeScript? [yes / no, JavaScript is fine]"

### 2. Product Vision Workshop
Tell the user: "Let me help you define the product vision — this guides the Requirements Engineer during refinement. Answer these questions as briefly or thoroughly as you like."

Ask (AskUserQuestion):
1. "Who are the primary users of this project? What's their technical level?"
2. "What core problem does it solve? How do users deal with this today?"
3. "What's the main value proposition — what makes this better than alternatives?"
4. "List 3-5 key goals (what success looks like)."
5. "What is explicitly OUT of scope? (what will you NOT build?)"

Write `docs/VISION.md` from the template, filled with the user's answers.

### 3. Architecture Decision
Based on project type and language, present an opinionated recommendation:

**TypeScript Web API:**
> Recommended: Clean Architecture + Express/Fastify + Zod validation + Vitest + Prisma/Drizzle
> - `src/domain/` — business logic (no framework dependencies)
> - `src/application/` — use cases / services
> - `src/infrastructure/` — database, external APIs
> - `src/api/` — HTTP layer (routes, middleware, validators)

**TypeScript Frontend:**
> Recommended: React + Zustand/Signals + TailwindCSS + Vitest + Playwright
> - Feature-based structure: `src/features/{name}/`
> - No global Redux store — colocate state

**TypeScript CLI:**
> Recommended: Commander.js + Zod + Vitest
> - Command pattern: `src/commands/{name}.ts`

**Python:**
> Recommended: FastAPI + Pydantic v2 + SQLAlchemy 2 + pytest + Ruff + mypy strict

**Rust:**
> Recommended: workspace layout, tokio for async, thiserror for errors, serde for serialization

**C++:**
> Recommended: CMake + Catch2 + clang-tidy + clang-format

Show the recommendation. Ask: "Use this architecture? [yes / customize / different approach]"
If customize/different: ask what they want to change.

Create `docs/dev/architecture.md` and `docs/dev/adr/ADR-001-architecture.md` documenting the decision.

### 4. Tech Stack Finalization
Based on language and architecture, ask:
1. **Testing**: Unit only / Unit + Integration / Unit + Integration + E2E
2. **Documentation size**: Markdown files (simple, recommended for most) / MkDocs HTML site (for large projects)
3. **Monorepo?**: No (single package) / Yes (workspaces)

### 5. Release & Deploy Setup
Ask (AskUserQuestion):
1. **Release type**: npm package / PyPI package / GitHub Release (binary/tag) / Docker image / Internal only
2. **Deploy**: No deploy / Manual steps / Vercel / AWS / Other cloud / Self-hosted server
3. **Branching model**: main-only (simpler — features merge into main, releases tagged on main) / Git Flow (features merge into `develop`; `/release` merges develop → `master`, so master's tip always equals the latest release)

Create:
- `docs/workflow/release.md` from template, filled with their answers
- `docs/workflow/deploy.md` from template (if deploy is not "no deploy")

Select the matching release CI template (`templates/github/release-{type}.yml`).

### 6. Create Project Structure

**Directory layout:**
```
{project-name}/
├── src/
│   └── CLAUDE.md          (code conventions)
├── tests/
│   └── CLAUDE.md          (testing conventions)
├── docs/
│   ├── VISION.md          (already written)
│   ├── workflow/
│   │   ├── README.md
│   │   ├── lifecycle.md
│   │   ├── conventions.md
│   │   ├── quality.md
│   │   ├── release.md     (already written)
│   │   └── deploy.md      (if applicable)
│   ├── dev/
│   │   ├── architecture.md (already written)
│   │   ├── setup.md
│   │   ├── style-guide.md
│   │   └── adr/
│   │       └── ADR-001-architecture.md (already written)
│   ├── user/
│   │   └── README.md
│   └── specs/
│       ├── backlog/
│       ├── ready/
│       └── completed/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── release.yml
│   ├── dependabot.yml
│   └── ISSUE_TEMPLATE/
│       ├── feature.md
│       └── bug.md
├── .claude/
│   ├── settings.json
│   ├── hooks/
│   ├── agents/
│   ├── skills/
│   ├── workflow-source.json
│   └── memory/
│       ├── decisions.md
│       ├── context.md
│       ├── gotchas.md
│       └── tech-debt.md
├── CHANGELOG.md
├── CLAUDE.md
├── CONTRIBUTING.md
└── README.md              (project README — first thing visitors see)
```

Plus shared scripts:
- `scripts/claude-loop.sh` ← from `templates/scripts/claude-loop.sh`

Plus language-specific files:
- TypeScript: `package.json`, `tsconfig.strict.json`, `eslint.config.js`, `.prettierrc`, `src/version.ts` (auto-generated), `scripts/generate-version.js`
- Python: `pyproject.toml`, `src/{package_name}/__init__.py`, `src/{package_name}/version.py`
- Rust: `Cargo.toml` (with workspace if monorepo)
- C++: `CMakeLists.txt`, `.clang-format`, `src/version.h.in`

Copy matching configs from `templates/configs/`, filling in `{{PROJECT_NAME}}` placeholders.

**TypeScript only:** also copy:
- `templates/configs/package.json.template` → `package.json` (fill in name + description)
- `templates/configs/generate-version.js` → `scripts/generate-version.js`
- Create empty `src/version.ts` (will be auto-generated on first build)

**Also copy per language:**
- `templates/gitignore/{language}.gitignore` → `.gitignore`

### 7. Write Root CLAUDE.md and README.md
Create root `CLAUDE.md` from `templates/CLAUDE.md.template`, filling in:
- Project name + description
- Tech stack
- Architecture summary (one paragraph)

Create root `README.md` from `templates/README.md.template`, filling in project name, description, tech stack, `{{GITHUB_REPO}}` (or removing the CI badge line for local-only repos), `{{WORKFLOW_REPO}}`, and `{{LICENSE}}`. Leave `{{INSTALLATION}}` / `{{USAGE_EXAMPLE}}` as short honest placeholders for a brand-new project — `/implement` and the documentation-writer keep them current later.

### 8. Create Memory Files
Write initial `.claude/memory/decisions.md` with the architecture and tech stack decisions made in this session.

Write `.claude/memory/context.md` noting this is a fresh project init.

### 9. Initial Backlog Brainstorm
Tell the user: "Let's create some initial backlog items from your vision. I'll suggest some; accept, reject, or add your own."

Generate 6-10 initial feature ideas based on:
- The product vision (goals, target users, core value proposition)
- The project type and typical features for that type
- Any features explicitly mentioned by the user

Present them interactively (same pattern as `/brainstorm`). Accepted ideas → create spec files in `docs/specs/backlog/`.

Note: the IDs created here (FEAT-001, FEAT-002, …) start the project's ID sequence — later `/draft` calls continue counting from the highest existing ID. In unsupervised/automated runs this step may be skipped; the sequence then starts with the first `/draft`.

### 10. GitHub Repository Creation (if requested)
```
gh repo create {project-name} --{public|private} --source=. --remote=origin
```

Create GitHub labels (`--force` updates labels that already exist, e.g. the default `bug` label):
```
gh label create feature --force --color 0075ca --description "New feature"
gh label create bug --force --color d73a4a --description "Bug report"
gh label create backlog --force --color e4e669 --description "In backlog"
gh label create refining --force --color 0075ca --description "Being refined"
gh label create ready --force --color 0e8a16 --description "Ready to implement"
gh label create "in-progress" --force --color fbca04 --description "Being implemented"
gh label create done --force --color cfd3d7 --description "Implemented and merged"
gh label create small --force --color bfd4f2 --description "Small effort"
gh label create medium --force --color d4c5f9 --description "Medium effort"
gh label create large --force --color e99695 --description "Large effort"
```

### 11. Copy Docs Templates
From `templates/`:
- `workflow/README.md.template` → `docs/workflow/README.md`
- `workflow/lifecycle.md.template` → `docs/workflow/lifecycle.md`
- `workflow/conventions.md.template` → `docs/workflow/conventions.md`
- `workflow/quality.md.template` → `docs/workflow/quality.md` (fill in test strategy)
- `dev/architecture.md.template` → `docs/dev/architecture.md` (filled in by step 3)
- `dev/setup.md.template` → `docs/dev/setup.md`
- `dev/style-guide.md.template` → `docs/dev/style-guide.md`
- `dev/adr/ADR-001.md.template` → `docs/dev/adr/ADR-001-architecture.md` (filled in by step 3)
- `dev/user-readme.md.template` → `docs/user/README.md`
- `CHANGELOG.md.template` → `CHANGELOG.md`
- `src-claude.md.template` → `src/CLAUDE.md`
- `tests-claude.md.template` → `tests/CLAUDE.md`
- `github/issue-feature.md` → `.github/ISSUE_TEMPLATE/feature.md`
- `github/issue-bug.md` → `.github/ISSUE_TEMPLATE/bug.md`

### 12. Install Workflow Infrastructure
Copy to `.claude/`:
- All agent files from this plugin's `agents/`
- All skill directories from this plugin's `skills/` (preserve the `{name}/SKILL.md` directory structure)
- All hook scripts from this plugin's `templates/hooks/` (auto-format, protect-files, completeness-check, session-start, usage-guard, statusline)
- `templates/hooks/hooks.json` → `.claude/settings.json` (if `.claude/settings.json` already exists, merge the `hooks` and `statusLine` keys into it — keep an existing `statusLine` if the user has one)

Write `.claude/workflow-source.json`. Read the `repository` and `version` fields from **this plugin's own `.claude-plugin/plugin.json`** (in the plugin root — the directory this skill was loaded from). Do not invent the URL; if `.claude-plugin/plugin.json` cannot be found or has no `repository`, leave `repo` empty and note it in the report.
```json
{ "repo": "{repository from plugin.json}", "version": "{version from plugin.json}", "installed": "{today}" }
```

Initialize memory files with the decisions made during this session:
- `.claude/memory/decisions.md`
- `.claude/memory/context.md` (project created, ready to start)
- `.claude/memory/gotchas.md` (empty)
- `.claude/memory/tech-debt.md` (empty)

Make hooks executable: `chmod +x .claude/hooks/*.sh`
Copy `templates/scripts/claude-loop.sh` → `scripts/claude-loop.sh` and make it executable: `chmod +x scripts/claude-loop.sh`

### 13. MkDocs Setup (if user chose HTML docs)
```
pip install mkdocs-material
mkdocs new .
```
Configure `mkdocs.yml` for Material theme with the docs/ structure.
Add `mkdocs serve` to `docs/dev/setup.md`.

### 14. Initial Commit
```
git add -A
git commit -m "chore: initialize project with claude-workflow infrastructure"
```

If GitHub remote configured:
```
git push -u origin main
```

**If the user chose Git Flow** (step 5 branching model):
```
git checkout -b develop
```
Only if a GitHub remote exists (`git remote get-url origin` succeeds):
```
git push -u origin develop
gh repo edit --default-branch develop
```
For local-only repos skip the push/default-branch steps — `develop` simply being the checked-out working branch is sufficient.

Document in `docs/workflow/release.md`: feature branches target `develop`; `/release` merges `develop` → `master` so the tip of `master` always equals the latest release. Stay on `develop` for further work.

### 15. Report
```
Project initialized ✓
{project-name}

Created:
  Docs: VISION.md, architecture.md, ADR-001, workflow docs
  Config: {tsconfig.strict.json|pyproject.toml|CMakeLists.txt}
  CI: .github/workflows/ci.yml + release.yml
  Infrastructure: .claude/ (agents, skills, hooks, memory)
  Backlog: {N} initial items in docs/specs/backlog/
  {GitHub repo: https://github.com/.../...}

Workflow commands:
  /brainstorm           generate more backlog ideas
  /refine FEAT-001      refine first backlog item
  /draft feature "..."  add raw ideas quickly
```
