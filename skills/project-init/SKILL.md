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

### 0.1 Model Tier for Design Phase (Supervised Mode Only)

Skip this step in unsupervised mode.

Explain and ask (AskUserQuestion):

> "The **design phase** (vision workshop, architecture decisions) benefits from high-quality reasoning.  
> The **scaffolding phase** (file creation, template copying, git setup) will automatically run on a Sonnet subagent to save tokens — your session model does not affect it.  
>  
> Which model tier do you want for the design phase?"

Options:
- **Session model** (recommended — proceed as-is; good if already on Opus/Sonnet)
- **Switch to Opus / Fable** — strongest reasoning; ideal for complex domains or tricky architecture decisions
- **Switch to Sonnet** — balanced cost/quality; good default
- **Switch to Haiku** — cheapest; fine when requirements are already clear and straightforward

If the user chooses a specific model: tell them to run `/model opus`, `/model sonnet`, or `/model haiku` now, then confirm when ready. Wait for confirmation before proceeding.

### 0.5 Design Document Review (Optional)

Ask (AskUserQuestion): "Do you have any design documents, requirements, or notes to share before we start? (PRD, concept notes, wireframe descriptions, feature lists — anything goes.)"

If the user shares documents:

1. **Accept all input**: Ask for the document content (paste or describe) and any additional context, constraints, or special instructions.

2. **Analyze thoroughly** — extract and record:
   - Project name, description, type, primary language (if mentioned)
   - Target users, core problem, value proposition, goals, explicit non-goals
   - Architectural ideas, technology preferences, or constraints
   - Features, requirements, release/deploy intentions

3. **Evaluate critically** — before proceeding, think independently:
   - Are the goals realistic given the stated scope?
   - Are there internal contradictions or missing pieces?
   - Is the scope appropriate (too broad / too narrow)?
   - What are 3-5 concrete improvements that would strengthen the project?
   - Would you recommend a different approach for any stated decision?

4. **Present your analysis**: Summarize what you understood, share your evaluation (strengths and concerns), and list your improvement suggestions. Ask the user to confirm or clarify before moving on.

5. **Pre-fill subsequent steps** from the confirmed information:
   - Fields that are clearly defined in the document → **skip the question entirely** (display the derived value with a brief note like "From design doc: …")
   - Fields with a reasonable pre-selection → **show the pre-selected value** and ask the user to confirm or change it
   - Fields not covered → ask normally as usual

Keep a mental note of which values came from the document so the user can always see what was derived vs. what they still need to decide.

### 1. Project Basics
Ask the user (AskUserQuestion) — **skip questions already resolved in step 0.5; for pre-filled values, confirm rather than ask fresh**:
1. **Project name** (if not in args and not in design doc)
2. **Short description** (one sentence)
3. **Project type**: Web API / Web Frontend / CLI tool / Library / Desktop App / Other
4. **Primary language**: TypeScript (recommended) / Python / Rust / C++ / Other

If user selects JavaScript instead of TypeScript: note "TypeScript is recommended for better AI-assistance and type safety. Use TypeScript? [yes / no, JavaScript is fine]"

### 2. Product Vision Workshop
Tell the user: "Let me help you define the product vision — this guides the Requirements Engineer during refinement. Answer these questions as briefly or thoroughly as you like."

**If vision elements were extracted from the design document in step 0.5, pre-fill the corresponding questions and ask the user to confirm or refine rather than asking from scratch.**

Ask (AskUserQuestion):
1. "Who are the primary users of this project? What's their technical level?"
2. "What core problem does it solve? How do users deal with this today?"
3. "What's the main value proposition — what makes this better than alternatives?"
4. "List 3-5 key goals (what success looks like)."
5. "What is explicitly OUT of scope? (what will you NOT build?)"

Write `docs/VISION.md` from the template, filled with the user's answers.

### 3. Architecture Decision
Based on project type and language, present an opinionated recommendation. **Consider any architectural ideas or technology preferences from the design document when making the recommendation.**

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
Ask (AskUserQuestion) — **pre-select values inferred from the design document (step 0.5) and ask user to confirm or change**:
1. **Release type**: npm package / PyPI package / GitHub Release (binary/tag) / Docker image / Internal only
2. **Deploy**: No deploy / Manual steps / Vercel / AWS / Other cloud / Self-hosted server
3. **Branching model**: main-only (simpler — features merge into main, releases tagged on main) / Git Flow (features merge into `develop`; `/release` merges develop → `master`, so master's tip always equals the latest release)

Create:
- `docs/workflow/release.md` from template, filled with their answers
- `docs/workflow/deploy.md` from template (if deploy is not "no deploy")

Select the matching release CI template (`templates/github/release-{type}.yml`).

### 5b. Hand Off to Scaffolder

All design decisions are now complete. Write a **1–3 sentence architecture summary paragraph** capturing: stack choices, key layer/module structure, and primary conventions. This will go into the project's root CLAUDE.md — write it with that audience in mind.

Then determine:
- `GITIGNORE_TEMPLATE`: `typescript` | `python` | `rust` | `cpp`
- `CI_LANGUAGE_TEMPLATE`: `typescript` | `python` | `rust` | `cpp`
- `RELEASE_CI_TEMPLATE`: `release-npm` | `release-pypi` | `release-github` | `none`
- `PLUGIN_SOURCE_DIR`: the absolute path to this plugin's root directory (the directory containing `agents/`, `skills/`, `templates/`). Determine it from the path of this SKILL.md file (go up two directories from `skills/project-init/`).
- `TARGET_DIR`: the absolute path to the new project directory.

Invoke the `project-scaffolder` agent with this prompt (fill in every `{…}` placeholder):

```
[PROJECT DECISIONS]
PROJECT_NAME: {name}
PROJECT_DESCRIPTION: {one-sentence description}
PROJECT_TYPE: {Web API | Web Frontend | CLI tool | Library | Desktop App | Other}
LANGUAGE: {TypeScript | Python | Rust | C++ | Other}
ARCHITECTURE_LABEL: {e.g. "Clean Architecture + Express + Zod + Vitest + Prisma"}
ARCHITECTURE_SUMMARY: {the 1–3 sentence paragraph you just wrote}
TESTING_SCOPE: {Unit only | Unit + Integration | Unit + Integration + E2E}
DOCS_TYPE: {Markdown | MkDocs HTML}
MONOREPO: {No | Yes}
RELEASE_TYPE: {npm | pypi | github | docker | internal}
DEPLOY: {none | manual | vercel | aws | other | self-hosted}
BRANCHING_MODEL: {main-only | git-flow}
GITHUB_REPO: {yes-public | yes-private | no}
PLUGIN_SOURCE_DIR: {absolute path determined above}
TARGET_DIR: {absolute path to the new project directory}
GITIGNORE_TEMPLATE: {typescript | python | rust | cpp}
CI_LANGUAGE_TEMPLATE: {typescript | python | rust | cpp}
RELEASE_CI_TEMPLATE: {release-npm | release-pypi | release-github | none}
TODAY: {today's date, YYYY-MM-DD}
WORKFLOW_REPO: {repository field from .claude-plugin/plugin.json}
WORKFLOW_VERSION: {version field from .claude-plugin/plugin.json}

[TASK]
Create the full project structure: directories, language-specific configs, CI templates, docs
templates, root CLAUDE.md and README.md, workflow infrastructure (.claude/ with agents/skills/hooks/
memory), and the initial git commit. Full instructions are in your agent definition.
```

Wait for the agent to complete and review its report before proceeding.

Run `/reload-skills` so Claude Code picks up the newly installed skills and agents from `.claude/` without requiring a session restart. After the reload, all workflow commands (`/draft`, `/refine`, `/implement`, etc.) are immediately available.

### 9. Initial Backlog — Four-Phase Structure

> **Supervised mode:** Scaffolding is complete. If you switched to a different model at step 0.1 and want to switch back for this creative phase, run `/model {model}` now.

Explain the four-phase approach to the user, then generate and review the backlog phase by phase.

**The four milestones (stored as `version:` in each spec):**

| version | Name | Goal |
|---------|------|------|
| `tech-backbone` | Technical Backbone | Deploy a blank/template version of the app — just enough to verify the architecture, CI/CD pipeline, and infrastructure are working. The user manually confirms the base is solid before real features are built. |
| `WS` | Walking Skeleton | The simplest possible end-to-end implementation of every major workflow. No polish, no edge cases — but every important user journey is navigable so the user can confirm the direction is correct. |
| `MVP` | MVP | All use cases complete and usable. Skip comfort features, advanced automation, and polish. The core product is testable and buildable. |
| `1.0.0` | 1.0.0 | Everything else from the design phase needed to reach version 1.0.0, not required for the MVP. Added so nothing is lost — the user decides which to pursue after the MVP is validated. Items that belong to future versions beyond 1.0.0 get a version string like `1.1.0`, `2.0.0`, etc. |

**Generate proposed items for each milestone** based on the product vision, architecture decisions, and any design documents from step 0.5:

- **tech-backbone (3–6 items):** Build system working, CI green (lint/type-check/test), core infrastructure provisioned (database, auth provider, cloud services — specific to the project type and deploy target from steps 3–5), release/deploy pipeline end-to-end, smoke test / health check endpoint so the user can verify the skeleton is alive in the deployed environment.

- **WS (3–7 items):** Identify the major user workflows from the vision (the "happy paths" — each important use case). One spec per workflow, implemented at the minimum fidelity that proves the path works. Keep these thin: real data flow, real UI screens, but no validation, no error handling, no styling beyond functional.

- **MVP (4–10 items):** For each WS workflow, add the items that make it production-quality: input validation, error handling, data persistence, user feedback. Also cover any use cases from the design doc not yet addressed. Omit comfort features, advanced automation, and anything "nice to have."

- **1.0.0 (5–15 items):** Everything else from the design documents. For items that clearly belong to a later version (e.g. a major new capability planned for 1.1), assign the appropriate version string (e.g. `1.1.0`) instead of `1.0.0`.

**Present milestone by milestone.** For each:
1. State the milestone name (`tech-backbone` / `WS` / `MVP` / `1.0.0`) and its one-sentence goal.
2. List all proposed items with a brief rationale for each.
3. Ask (AskUserQuestion): "{milestone} items — what would you like to do? [Accept all / Let me choose / Add or change items / Skip]"
   - **Accept all**: proceed.
   - **Let me choose**: user selects which items to keep; optionally adds new ones.
   - **Add or change items**: accept additions/modifications, then confirm.
   - **Skip**: move to the next milestone without creating any items for this one.

**Create spec files for all accepted items:**
```
docs/specs/backlog/{TYPE}-{NNN}-{kebab-title}.md
```
Frontmatter:
```yaml
id: {TYPE}-{NNN}
type: feature
status: draft
version: {tech-backbone|WS|MVP|1.0.0|1.1.0|…}
created: {today}
updated: {today}
github_issue: ~
```
Body: write a one-sentence User Story based on the item's purpose. Leave Acceptance Criteria as `[To be defined in /refine]`.

IDs are sequential across all milestones (FEAT-001, FEAT-002, …) — later `/draft` calls continue from the highest existing ID.

If GitHub remote exists: create GitHub issues for all accepted items (`gh issue create --label "feature,backlog"`).

After all milestones: print a summary — version string, item count, and ID range for each.

### 10. GitHub Repository Creation (if requested)
```
gh repo create {project-name} --{public|private} --source=. --remote=origin
git push -u origin main
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

**If the user chose Git Flow** (step 5 branching model):
```
git checkout -b develop
git push -u origin develop
gh repo edit --default-branch develop
```
For local-only repos: create `develop` branch locally but skip the push/default-branch steps.

Update `docs/workflow/release.md` noting feature branches target `develop` and the `/release` flow.

### 15. Report
```
Project initialized ✓
{project-name}

Design (main session):
  Docs: VISION.md, architecture.md, ADR-001, release.md
  Backlog: {N} items
    tech-backbone: {N} items
    WS:            {N} items
    MVP:           {N} items
    1.0.0+:        {N} items

Scaffolding (project-scaffolder agent):
  Config: {tsconfig.strict.json|pyproject.toml|CMakeLists.txt}
  CI: .github/workflows/ci.yml + release.yml
  Infrastructure: .claude/ (agents, skills, hooks, memory)
  Root files: CLAUDE.md, README.md, CONTRIBUTING.md
  Committed: yes (branch: {main|develop})

  {GitHub repo: https://github.com/.../...}

Workflow commands:
  /brainstorm           generate more backlog ideas
  /refine FEAT-001      refine first backlog item
  /draft feature "..."  add raw ideas quickly

→ Restart your Claude Code session now.
  Hooks, status line, and all skills are fully active only after a fresh
  session start. Close this session and reopen it in the project directory.
```
