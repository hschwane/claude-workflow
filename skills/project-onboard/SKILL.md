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

### 1. Analyze Existing Project
Invoke the `code-explorer` subagent to explore the project:

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

Ask (AskUserQuestion):
1. **Confirm tech stack** — "I detected {stack}. Is this correct?"
2. **GitHub** — "Does this project use GitHub? [yes/no]"
3. **Existing tests** — "I found {test info}. Should the workflow integrate with them? [yes / no, set up fresh]"
4. **Docs format** — "For workflow documentation, use: [markdown files (default) / MkDocs HTML]"

### 3. Install Workflow Infrastructure

**a) Copy from claude-workflow plugin:**
Create `.claude/` directory with:
```
.claude/
├── settings.json          ← from templates/hooks/hooks.json (merge `hooks` key if settings.json exists)
├── hooks/
│   ├── auto-format.sh     ← parses stdin JSON, formats by language
│   ├── protect-files.sh   ← blocks edits to .env, lock files, etc.
│   ├── completeness-check.sh
│   └── session-start.sh   ← shows in-progress work / auto-resume directive
├── agents/                ← copy all agent .md files
├── skills/                ← copy all skill directories (each as {name}/SKILL.md)
├── workflow-source.json
└── memory/
    ├── decisions.md
    ├── context.md
    ├── gotchas.md
    └── tech-debt.md
```

Write `.claude/workflow-source.json`:
```json
{ "repo": "{workflow_repo_url}", "version": "{current_version}", "installed": "{today}" }
```

Make hook scripts executable: `chmod +x .claude/hooks/*.sh`
Copy `templates/scripts/claude-loop.sh` → `scripts/claude-loop.sh` and make it executable: `chmod +x scripts/claude-loop.sh`

**b) Create workflow documentation** (from plugin templates/):
```
docs/workflow/
├── README.md         ← templates/workflow/README.md.template
├── lifecycle.md      ← templates/workflow/lifecycle.md.template
├── conventions.md    ← templates/workflow/conventions.md.template
└── quality.md        ← templates/workflow/quality.md.template
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
```

Write initial `.claude/memory/context.md`:
```markdown
# Project Context

## Overview
{project summary from analysis agent}

## Status
Onboarded on {today}. Ready to use workflow.
```

**e) Language-specific CI (if missing or user wants to add):**
Check `.github/workflows/` — if no CI exists, offer to create it.
Copy the matching `templates/github/ci-{language}.yml` as `.github/workflows/ci.yml`.

**f) Subdirectory CLAUDE.md files (if src/ and tests/ exist):**
Create `src/CLAUDE.md` with brief code convention note (user can expand).
Create `tests/CLAUDE.md` with testing pattern note.

**g) CONTRIBUTING.md (if not present):**
Create from `templates/CONTRIBUTING.md.template`.

**h) CLAUDE.md (if not present):**
Create root `CLAUDE.md` from template, filled with detected tech stack and architecture summary.
If CLAUDE.md already exists: offer to add the workflow commands table to it.

### 4. GitHub Setup (if applicable)
If GitHub remote exists:
- Create labels: `gh label create feature --force --color 0075ca` etc. (feature, bug, backlog, refining, ready, in-progress, done, small, medium, large — `--force` because defaults like `bug` already exist)
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
  /brainstorm              to analyze and fill the backlog
  /draft feature "title"   to add first items manually
  /workflow-update         to update to latest version later
```
