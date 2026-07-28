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
- Verify `git`, `gh` (GitHub CLI) are available (**required** — the workflow is git/GitHub based)
- If `gh` is not authenticated: `gh auth status` — if not logged in, prompt user to run `gh auth login`
- Check runtimes used by the quality gates and warn (do not block) if missing:
  - `node --version` and `npx --version` — needed for the JS/TS gates (`eslint`, `prettier`, `tsc`)
  - `python --version` (fall back to `python3 --version`, or `py --version` on Windows) — needed for the Python gates (`ruff`, `mypy`)
  - These are only relevant for the project's chosen language. If the stack is Rust/C++/other and neither runtime is present, that's fine — just note it. If the runtime for the chosen language is missing, print a clear warning (e.g. "⚠ node not found — JS/TS lint/type-check gates in /commit will be skipped until it's installed") and continue.
- Ask (in chat — plain message, wait for the reply): "Create a GitHub repository? [yes — public / yes — private / no, local only]"

### 0.1 Design-Phase Model Note (Supervised Mode Only)

Skip this step in unsupervised mode. Print once, non-blocking — do not ask:

> 💡 The design phase (vision, architecture) is interactive — the session model is what thinks. Sonnet is fine for straightforward projects; for a complex or novel domain, consider `/model opus` (or `best`) for the design phase, then switch back. The mechanical scaffolding runs on a Haiku subagent either way.

Continue immediately on the current model unless the user switches.

### 0.5 Design Document Review (Optional)

Ask (in chat — plain message, wait for the reply): "Do you have any design documents, requirements, or notes to share before we start? (PRD, concept notes, wireframe descriptions, feature lists — anything goes.)"

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
Ask the user (in chat — plain message, wait for the reply) — **skip questions already resolved in step 0.5; for pre-filled values, confirm rather than ask fresh**:
1. **Project name** (if not in args and not in design doc)
2. **Short description** (one sentence)
3. **Project type**: Web API / Web Frontend / CLI tool / Library / Desktop App / Other
4. **Primary language**: TypeScript (recommended) / Python / Rust / C++ / Other

If user selects JavaScript instead of TypeScript: note "TypeScript is recommended for better AI-assistance and type safety. Use TypeScript? [yes / no, JavaScript is fine]"

**Then create the project directory and work inside it.** Ask for the target path (default: `./{project-name-kebab}`), `mkdir -p` it, `cd` into it, and `git init`. Every path from here on — `docs/VISION.md`, `docs/dev/architecture.md`, the scaffolder's `TARGET_DIR` — is relative to it. Without this, steps 2–5 write into whatever directory the session happened to start in.

### 1.5 Load the matching guidelines — before designing anything
The project type and language are known now, so match guidelines **here**, not at scaffolding time: they shape the vision, the architecture and the backlog, and retrofitting them later is how a project ends up missing its baseline.

Read `{PLUGIN_SOURCE_DIR}/templates/guidelines/LIBRARY.md` and, if it exists, the user-global `~/.claude/guidelines/INDEX.md`. Match every trigger against what's known so far — project type, language, and the features/tech/deploy intentions from the design doc — and **read each matching guideline now**. Re-check once the architecture and deploy target are decided (steps 3–5) and read anything newly matched (e.g. `railway.md`).

Carry what you read into:
- **Vision (step 2)** — a guideline can sharpen scope or an explicit non-goal.
- **Architecture and deploy (steps 3–5)** — e.g. `service-architecture.md`'s layering, `ai-integration.md`'s interface rule, `railway.md`'s portability rule.
- **Backlog (step 7)** — **every "required" item in a matching guideline that the scaffold doesn't already provide becomes a ticket.** `app-baseline.md` alone yields several (logging, in-app changelog, an update mechanism, Claude-testable smoke access); `ui-frontend.md` says when a real design pass is due; `web-app-pwa.md` yields version display, update control and the access gate.

Guidelines stay **recommendations** — judge each against this project's real scale and say so when you reject one (see the guidelines `README.md`). What you must not do is silently skip them.

After scaffolding, the matching files are installed into the project's `.claude/guidelines/` with their INDEX rows (the scaffolder does this via `LIBRARY_GUIDELINES`; **copy matching global ones too**, since `~/.claude/` is ephemeral in cloud sessions).

### 2. Product Vision Workshop
Tell the user: "Let me help you define the product vision — this guides planning and implementation. Answer these questions as briefly or thoroughly as you like."

**If vision elements were extracted from the design document in step 0.5, pre-fill the corresponding questions and ask the user to confirm or refine rather than asking from scratch.**

Ask (in chat — plain message, wait for the reply):
1. "Who are the primary users of this project? What's their technical level?"
2. "What core problem does it solve? How do users deal with this today?"
3. "What's the main value proposition — what makes this better than alternatives?"
4. "List 3-5 key goals (what success looks like)."
5. "What is explicitly OUT of scope? (what will you NOT build?)"

Write `docs/VISION.md` from `templates/vision.md.template`, filled with the user's answers.

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

Create `docs/dev/architecture.md` (from `templates/dev/architecture.md.template`) documenting the decision — the structure, why it was chosen, and what it rules out. The one-line record goes to `.claude/memory/decisions.md` (the scaffolder seeds it); the reasoning lives here, where it is cheap to read and expensive to re-derive.

### 4. Tech Stack Finalization
Based on language and architecture, ask:
1. **Testing**: Unit only / Unit + Integration / Unit + Integration + E2E
2. **Documentation size**: Markdown files (simple, recommended for most) / MkDocs HTML site (for large projects)
3. **Monorepo?**: No (single package) / Yes (workspaces)

### 5. Release & Deploy Setup
Ask (in chat — plain message, wait for the reply) — **pre-select values inferred from the design document (step 0.5) and ask user to confirm or change**:
1. **Release type**: npm package / PyPI package / GitHub Release (binary/tag) / Docker image / Internal only
2. **Deploy**: Railway (Recommended) / No deploy / Manual steps / Vercel / AWS / Other cloud / Self-hosted server

   Railway is the preferred deploy target. When chosen, the scaffolder installs the Railway deployment **guideline** (`.claude/guidelines/railway.md`) and `railway.json` — that guideline holds all the details (scale-to-zero, EU region, URL = project name, watch-path exclusions, and the rule that Railway-specifics live behind a project-defined interface for portability). `/plan` reads it when a ticket touches deployment. No need to restate the values here — just set `deploy: railway` in the `workflow-settings` block and fill `docs/dev/deploy.md`.
3. **Branching model**: main-only (simpler — features merge into main, releases tagged on main) / Git Flow (features merge into `develop`; `/release` merges develop → `master`, so master's tip always equals the latest release)

**Then set two CI/release decisions — recommend by project type, confirm (don't belabor):**
- `CI_ON_CLAUDE` — should GitHub Actions also run on *Claude's* commits? **Default `no`** (Claude ran the identical `ci.sh` locally; save the minutes). **Recommend `yes` for a cross-platform library** where CI adds matrix/multi-env coverage local can't reproduce.
- `RELEASE_RUNNER` — **default `local`** (Claude runs `scripts/release.sh` in-session). Recommend `ci` only if the user wants publish secrets kept out of the session, or needs CI-only provenance/OIDC signing.

Create:
- `docs/dev/deploy.md` from `templates/dev/deploy.md.template` (if deploy is not "no deploy") — platform settings, deploy steps, rollback, health check and the required secrets

Select the matching release CI template: npm → `release-npm`, PyPI → `release-pypi`, GitHub Release → `release-github`; Docker image and Internal only have no release CI template — use `none`.

### 5b. Hand Off to Scaffolder

All design decisions are now complete. Write a **1–3 sentence architecture summary paragraph** capturing: stack choices, key layer/module structure, and primary conventions. This will go into the project's root CLAUDE.md — write it with that audience in mind.

Then determine:
- `GITIGNORE_TEMPLATE`: `typescript` | `python` | `rust` | `cpp`
- `CI_LANGUAGE_TEMPLATE`: `typescript` | `python` | `rust` | `cpp`
- `RELEASE_CI_TEMPLATE`: `release-npm` | `release-pypi` | `release-github` | `none`. **`release-runner: ci` requires a template other than `none`** — `/release` in `ci` mode dispatches `release.yml`, which would not exist. For a `docker` or `internal` release type, keep `release-runner: local`.
- `PLUGIN_SOURCE_DIR`: the absolute path to this plugin's root directory (the directory containing `agents/`, `skills/`, `templates/`). Determine it from the path of this SKILL.md file (go up two directories from `skills/project-init/`).
- `TARGET_DIR`: the absolute path to the new project directory.
- `LIBRARY_GUIDELINES`: the comma-separated list of library guidelines matched in **step 1.5**, now that the deploy target and architecture are settled — re-check `{PLUGIN_SOURCE_DIR}/templates/guidelines/LIBRARY.md` for anything the later decisions newly match. Typical matches: `app-baseline` for any project bigger than a small script/tool; `railway` if DEPLOY=railway; `plots-graphs` if the app renders charts/graphs/data-viz; `maps` if it shows an interactive map; `web-app-pwa` if it's a web app / PWA; `ui-frontend` if it has a UI to design; `changelog` if it should ship an in-app changelog; `ai-integration` if it integrates AI features; `telegram-bots` if it's a Telegram bot; `service-architecture` if it's a non-trivial backend/service with real business logic (Web API, bot, daemon — not a thin CLI/library); `logging` for anything beyond a small script; `background-jobs` if it has scheduled/periodic/background work or must handle graceful shutdown (plus any others added to LIBRARY.md later). Empty only for a genuinely tiny script. The scaffolder installs each (file + INDEX row) so `/plan` picks them up.

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
DEPLOY: {railway | none | manual | vercel | aws | other | self-hosted}
BRANCHING_MODEL: {main-only | git-flow}
GITHUB_REPO: {yes-public | yes-private | no}
PLUGIN_SOURCE_DIR: {absolute path determined above}
TARGET_DIR: {absolute path to the new project directory}
LIBRARY_GUIDELINES: {comma list computed from LIBRARY.md, or empty}
GITIGNORE_TEMPLATE: {typescript | python | rust | cpp}
CI_LANGUAGE_TEMPLATE: {typescript | python | rust | cpp}
RELEASE_CI_TEMPLATE: {release-npm | release-pypi | release-github | none}
CI_ON_CLAUDE: {no | yes}
RELEASE_RUNNER: {local | ci}
TODAY: {today's date, YYYY-MM-DD}
WORKFLOW_REPO: {owner/repo from plugin.json `repository`, with the https://github.com/ prefix stripped — the templates add it}
WORKFLOW_VERSION: {version field from .claude-plugin/plugin.json}

[TASK]
Create the full project structure: directories, language-specific configs, CI templates, docs
templates, root CLAUDE.md and README.md, workflow infrastructure (.claude/ with agents/skills/hooks/
memory), and the initial git commit. Full instructions are in your agent definition.
```

Wait for the agent to complete and review its report before proceeding.


### 6. Workflow Decisions Review (Supervised Mode Only)

Skip this step in unsupervised mode.

The scaffolder wrote the `workflow-settings` block in `CLAUDE.md` — the seven tunable
workflow settings, in the only place they live. Tell the user:
  • `/workflow-settings` shows them and explains the allowed values;
  • `/workflow-settings <name> <value>` changes one and follows through on the consequences;
  • the change is recorded as a dated entry in `.claude/memory/decisions.md`.

### 7. Initial Backlog — Four-Phase Structure

> **Supervised mode:** Scaffolding is complete. If you switched to a different model at step 0.1 and want to switch back for this creative phase, run `/model {model}` now.

Explain the four-phase approach to the user, then generate and review the backlog phase by phase.

**The four milestones (stored as `version:` in each spec):**

| version | Name | Goal |
|---------|------|------|
| `tech-backbone` | Technical Backbone | Deploy a blank/template version of the app — just enough to verify the architecture, CI/CD pipeline, and infrastructure are working. The user manually confirms the base is solid before real features are built. |
| `WS` | Walking Skeleton | The simplest possible end-to-end implementation of every major workflow. No polish, no edge cases — but every important user journey is navigable so the user can confirm the direction is correct. |
| `MVP` | MVP | All use cases complete and usable. Skip comfort features, advanced automation, and polish. The core product is testable and buildable. |
| `1.0.0` | 1.0.0 | Everything else from the design phase needed to reach version 1.0.0, not required for the MVP. Added so nothing is lost — the user decides which to pursue after the MVP is validated. Items that belong to future versions beyond 1.0.0 get a version string like `1.1.0`, `2.0.0`, etc. |

**Generate proposed items for each milestone** based on the product vision, architecture decisions, any design documents from step 0.5, **and the guidelines matched in step 1.5** — every "required" item in a matching guideline that the scaffold doesn't already provide needs a ticket here. Anything that makes later development or debugging easier goes in **`tech-backbone`** (see its list below); genuinely feature-shaped requirements go in the milestone they belong to (the real UI design pass by `MVP`/`1.0.0`, and so on). Name the source guideline in the item's rationale so the user can judge it; if you deliberately drop one as overkill for this project's scale, say that too rather than omitting it silently.

- **tech-backbone (5–10 items):** Build system working, CI green (lint/type-check/test), core infrastructure provisioned (database, auth provider, cloud services — specific to the project type and deploy target from steps 3–5), release/deploy pipeline end-to-end, smoke test / health check endpoint so the user can verify the skeleton is alive in the deployed environment.

  **Plus the developer-utility baseline — always here, never deferred.** These are what make every later ticket faster to build and debug, so they belong in the first milestone even though they aren't features. For anything bigger than a small script/tool, tech-backbone must include (see `app-baseline.md`, `logging.md`, `changelog.md`, `web-app-pwa.md`):
  - **Structured logging**, wired from the start, with per-module and runtime-adjustable levels — this is the debugging tool every later ticket relies on.
  - **Version visibility** — the running build's version + git sha, injected at build time and shown in the app.
  - **The update mechanism** for this architecture — for a web app/PWA the check-for-updates button with real feedback plus the update banner; otherwise the closest equivalent.
  - **The in-app changelog view**, with its backend source (`templates/ui/changelog-template.html` is the starting point).
  - **Claude-testable access to a live instance** — local run, or a QA/staging deployment kept separate from production.
  - The **access gate** if it's a private single-user app reachable from the internet, and **API token auth** for any exposed API.

  Skipping one of these needs a stated reason (a genuinely tiny tool, or the architecture makes it meaningless) — never "we'll add it later". Retrofitting logging or an update path into a half-built app is exactly the cost this milestone exists to avoid.

- **WS (3–7 items):** Identify the major user workflows from the vision (the "happy paths" — each important use case). One spec per workflow, implemented at the minimum fidelity that proves the path works. Keep these thin: real data flow, real UI screens, but no validation, no error handling, no styling beyond functional.

- **MVP (4–10 items):** For each WS workflow, add the items that make it production-quality: input validation, error handling, data persistence, user feedback. Also cover any use cases from the design doc not yet addressed. Omit comfort features, advanced automation, and anything "nice to have."

- **1.0.0 (5–15 items):** Everything else from the design documents. For items that clearly belong to a later version (e.g. a major new capability planned for 1.1), assign the appropriate version string (e.g. `1.1.0`) instead of `1.0.0`.

**Present milestone by milestone.** For each:
1. State the milestone name (`tech-backbone` / `WS` / `MVP` / `1.0.0`) and its one-sentence goal.
2. List all proposed items with a brief rationale for each.
3. Ask (in chat — plain message, wait for the reply): "{milestone} items — what would you like to do? [Accept all / Let me choose / Add or change items / Skip]"
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
Body: write a one-sentence User Story based on the item's purpose. Leave Acceptance Criteria as `[To be defined in /plan]`.

IDs are sequential across all milestones (FEAT-001, FEAT-002, …) — later `/draft` calls continue from the highest existing ID.

If GitHub remote exists: create GitHub issues for all accepted items (`gh issue create --label "feature,backlog"`).

After all milestones: print a summary — version string, item count, and ID range for each.

### 8. GitHub Repository Creation (if requested)
```
gh repo create {project-name} --{public|private} --source=. --remote=origin
git push -u origin main
```

Create GitHub labels (`--force` updates labels that already exist, e.g. the default `bug` label):
```
gh label create feature --force --color 0075ca --description "New feature"
gh label create bug --force --color d73a4a --description "Bug report"
gh label create backlog --force --color e4e669 --description "In backlog"
gh label create ready --force --color 0e8a16 --description "Ready to implement"
gh label create "in-progress" --force --color fbca04 --description "Being implemented"
gh label create done --force --color cfd3d7 --description "Implemented and merged"
```

Fill the README CI badge: replace `{{GITHUB_REPO}}` in `README.md` with `{owner}/{repo}` of the repo just created, then commit (`docs: fill CI badge repo`). (The scaffolder leaves the placeholder because the repo does not exist yet at scaffolding time.)

**If the user chose Git Flow** (step 5 branching model):
```
git checkout -b develop
git push -u origin develop
gh repo edit --default-branch develop
```
For local-only repos: create `develop` branch locally but skip the push/default-branch steps.

Set `branching: git-flow` in the `workflow-settings` block — `/release` reads it from there.

### 9. Report
```
Project initialized ✓
{project-name}

Design (main session):
  Docs: VISION.md, dev/architecture.md, dev/code-style.md, dev/setup.md{, dev/deploy.md}
  Backlog: {N} items
    tech-backbone: {N} items
    WS:            {N} items
    MVP:           {N} items
    1.0.0+:        {N} items

Scaffolding (project-scaffolder agent):
  Config: {tsconfig.strict.json|pyproject.toml|CMakeLists.txt}
  CI: .github/workflows/ci.yml{ + release.yml if a release template was used}
  Infrastructure: .claude/ (agents, skills, hooks, memory)
  Root files: CLAUDE.md, README.md, CONTRIBUTING.md
  Committed: yes (branch: {main|develop})

  {GitHub repo: https://github.com/.../...}

Workflow commands:

  /plan FEAT-001        plan the first backlog item
  /draft feature "..."  add raw ideas quickly

→ Restart your Claude Code session now.
  Hooks, status line, and all skills are fully active only after a fresh
  session start. Close this session and reopen it in the project directory.
```
