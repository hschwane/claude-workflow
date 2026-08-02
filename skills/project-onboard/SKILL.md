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
2. **GitHub** — "Does this project use GitHub? [yes — public / yes — private / no]" (the public/private answer is the `GITHUB_REPO` value the scaffolder needs, not a yes/no)
3. **Existing tests** — "I found {test info}. Should the workflow integrate with them? [yes / no, set up fresh]"
4. **Docs format** — "For workflow documentation, use: [markdown files (default) / MkDocs HTML]"
5. **Test scope** — "What test levels should the workflow use for this project? [Unit only / Unit + Integration / Unit + Integration + E2E]" — pre-select from the test setup detected in step 1, and say that step 3c may narrow it to what the gate can actually run.
6. **Branching** — "main-only or git-flow?" — detect from the existing branches and offer that as the default.
7. **Deploy target** — "Where does this deploy? [railway / vercel / aws / self-hosted / manual / none]" — detect from `railway.json`, a Procfile, a Dockerfile, a deploy workflow.
7b. **Deploy details** — only when the answer to 7 is not `none`: "What URL or command answers for a deployed instance, and what secret does the deploy need?" `release.sh`'s healthcheck must assert the released version against something, and `docs/dev/deploy.md` ships `{{HEALTH_CHECK_URL}}`, `{{DEPLOY_SECRET_NAME}}` and `{{PLATFORM_SETTINGS}}` — in init the main session has already written that doc, but here nothing has, so an unasked question becomes an invented hostname.
8. **Release** — "How does a release publish? [npm / pypi / github release / docker / internal / none]", and "run releases locally or via Actions? [local (default) / ci]".
9. **GitHub owner** — only when question 2 was yes: "Which owner will the repo live under?" (`gh api user --jq .login` is the default). `docs/dev/setup.md`'s clone URL needs it and the scaffolder is forbidden from guessing one.

**Everything the scaffolder needs must come from here or from the analysis.** It takes the same decisions block `/project-init` builds, and it does not improvise: a field you cannot fill is a question you have not asked. Derive what you can and ask for the rest rather than guessing:
- from the step 1 analysis: `MONOREPO`, `PROJECT_TYPE`, `ARCHITECTURE_LABEL`/`SUMMARY`, `GITIGNORE_TEMPLATE` and `CI_LANGUAGE_TEMPLATE` (the language), `version-source` (the manifest that exists), `TRUNK_BRANCH` (`git branch --show-current`), `BRANCHING_MODEL`
- fixed or conditional: `ci-on-claude: no`; `REVIEW_DEPTH: critical-only` (the marked default — an onboarded project starts where every existing project already effectively is); `REFERENCE_ENV` only ever `yes` under `git-flow`, and only if the user wants one; `RELEASE_CI_TEMPLATE` is `none` unless the release publishes to a registry; `COPYRIGHT_HOLDER` only if a LICENSE already exists, since onboard never creates one
- from the plugin's own `.claude-plugin/plugin.json`: `WORKFLOW_REPO` (bare `owner/repo`) and `WORKFLOW_VERSION`
- mechanically, without asking: `PROJECT_NAME` (the directory or the manifest), `LANGUAGE`, `TODAY`, `PLUGIN_SOURCE_DIR`, `TARGET_DIR`. `PROJECT_DESCRIPTION` needs judgment — draft it from the README and confirm it, don't invent one silently.

Several of these land in the `workflow-settings` block of the auto-loaded root `CLAUDE.md` and drive `/verify`, `/pr` and `/release`. Take the exact list and each default from `/workflow-settings` rather than counting them here — a number in prose goes stale the first time a setting is added or removed.

### 3. Install Workflow Infrastructure

The mechanical install is the same one `/project-init` does, so **it is not duplicated here** — this skill owns only what is specific to an existing codebase: merging its `CLAUDE.md`, making its real commands into a working gate, and reconciling its existing CI. Everything else is delegated, because a second hand-written copy of the install is a second copy that drifts, and only one of them gets tested.

#### 3a. Delegate the mechanical install

**First, install dependencies.** Onboard mode skips the manifest, so nothing else installs them — and `ci.sh` cannot run a single check without `node_modules`. Run the project's install (`npm install` / `uv sync` / `cargo fetch`) and, if its CI uses `npm ci`/`--locked` and no lockfile is committed, commit one.

**Guidelines need no decision before delegating** — the scaffolder installs the plugin's whole library unconditionally. The only thing to gather first is any **user-global** guideline (`~/.claude/guidelines/`) that fits this codebase: pass those absolute paths as `GLOBAL_GUIDELINES`, since they live outside the plugin and `~/.claude/` is ephemeral in cloud sessions. Matching the library against the codebase still happens, in 3e — but for *reading*, not for installing.

Then invoke the `project-scaffolder` agent with `MODE: onboard` (read that agent's **Onboard mode** section: never overwrite anything that exists, skip what the project provides, do not create the init-only artifacts, install the rest). Pass the decisions block from its **Input Fields** table, filled from the step 1 analysis and the step 2 answers, plus:

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

**Fill `docs/VISION.md`.** The scaffolder leaves a bracket stub (`[What problem does this solve?]`), and those placeholders are not `{{…}}` so no token sweep catches them. `/ship` reads this file unconditionally to derive tickets from a topic — boilerplate there produces boilerplate tickets. Draft Problem / Audience / Goals / Non-goals from the analysis and the existing README, and flag it in the step 6 report as *drafted from the codebase — confirm before the first `/plan`*.

  Show the mapping and the result before writing, and **name every piece and its destination in the step 6 report**. Nothing may be dropped for want of a home.

**Then fix what pointed at it.** A README section reading "## Deploy — see CLAUDE.md" is now a dangling reference. Grep the repo for inbound links to every section you moved and update them; list the repairs in the report.

  **Moving a rule out of `CLAUDE.md` changes when it fires.** It was on every turn; `decisions.md` is read at `/plan`, `src/CLAUDE.md` only when work touches `src/`. For most rules that is the right trade. For a **safety, privacy or legal** constraint ("never log booking payloads — they contain customer names") it is not: offer to keep a one-line version in the `identity` block as well, and say in the report that its always-loaded status was at stake.

**Do not rewrite `.claude/memory/decisions.md` after this.** It now holds the project's own house rules. Anything further — the tech-stack summary, observed patterns — is *appended* as one more dated entry.

**The one exception is the `**Topics:**` index line, which you must extend.** The scaffolder set it to `architecture`; a head-only reader stops there and never sees the rules you just appended, which is precisely the mechanism 3b relies on for a rule to reach `/plan`. Add a topic per entry (`no-orm, money, booking-ids, logging-pii, …`).

**Write the test directory's `CLAUDE.md` yourself** — into the project's actual directory (`test/`, `tests/`, `spec/`), not a `tests/` the project does not have. `templates/tests-claude.md.template` describes a `tests/unit` + `tests/integration` split as prose rather than tokens, which is true for a project `/project-init` created and false for most existing ones: rewrite the Layout and the `ci.sh` sentence to match the suite that is actually here. This is why the file is carved out of the scaffolder's work alongside `CLAUDE.md` and `README.md`. Record the directory name as a decision too, so `/plan` knows it.

#### 3c. Make the gate real — the part that actually takes judgment

`scripts/ci.sh` is installed but unfilled. Fill each `check <command>` line with **this project's own commands**, taken from its `package.json` scripts / `Makefile` / `pyproject.toml` / `Cargo.toml`. Keep the `check ` prefix — that is what makes the script count its own work. Use the names that exist here (`npm run fmt`, not `npm run format:check`) and go through the package manager, never a bare binary — `eslint`/`prettier`/`tsc`/`vitest` are not on `PATH` in CI.

**`{{UNIT_TESTS_SELECTED}}` is the one stage with no equivalent in the project's own scripts.** `fast` runs it instead of the whole unit suite: the runner's changed-files mode, which walks the real import graph — `vitest related --run`, `jest --onlyChanged`, `pytest --picked`. Where the project's runner has no such mode, **fill it with the same command as `{{UNIT_TESTS}}`**; degrade to running more, never to running less. Never leave it unfilled (a live placeholder kills every `fast` gate with "command not found") and never leave it empty (a gate that silently runs no tests). Where the runner has a `--passWithNoTests` style flag, set it so an empty selection *fails* — the defaults disagree, and two of the common ones treat "collected nothing" as success.

`{{GENERATE_SOURCES}}` keeps the **`prepare `** prefix (it is guarded separately, because a bare command that fails there is ignored and the gate then checks missing sources): fill it with the command that produces anything gitignored-but-required (a generated version module, a compiled schema, a codegen step) so lint and typecheck see it in a fresh CI clone, or delete the line — **and if you delete it, delete the `prepare()` helper too**, or the project ships a defined-but-never-called function. Then delete the authoring notes from both scripts — the comment block down to and including the `# --- end of authoring notes ---` rule, plus every `# e.g.` line and the narration for any step you removed. Nothing below that rule.

Then `bash -n scripts/ci.sh` and run `scripts/ci.sh fast`. Three things go wrong on a real codebase, and each needs a decision rather than a shrug:

- **No command exists for a stage** (common: no `typecheck` script). Add one to the project's manifest rather than inlining a bare binary, and say you did. If the stage genuinely does not apply, delete its line — deleting them all still parses, and the script's own check counter then reports an empty gate honestly.
- **An existing command fails.** That is a pre-existing break which the gate has just made load-bearing. Show the failure, propose the smallest fix, and get agreement before editing `package.json` or dependencies. Do not quietly work around it.
- **The healthcheck cannot assert a version this project does not expose.** `scripts/healthcheck.sh` refuses to confirm a version unless a probe compares against it, and many existing projects report no version at runtime. Don't weaken it to a bare liveness probe: write the `version_probe` form, add a blocking backlog ticket for version visibility, and record it in `tech-debt.md`. `/release` will stop until that ships — deliberately, and the user should hear it in the step 6 report rather than discover it at their first release.
- **The tool is installed but its config is missing** (an `eslint` dependency and a `lint` script but no `eslint.config.js` — common on a repo that drifted). **Do not copy `templates/configs/eslint.config.js`.** It is written for a fresh install: it pulls in `typescript-eslint` and `@eslint/js@10`, which ERESOLVE-conflicts with an existing `eslint@9`, and its type-checked rule sets then fail on any test tree the project's `tsconfig.json` does not include. Author a minimal config *for this project* instead — pinned to the major it already has, and non-type-checked where the test files sit outside the TypeScript project. The plugin's configs are for projects the plugin created.
- **A missing lockfile.** If CI uses `npm ci` / `uv sync --locked` / `cargo --locked` and no lockfile is committed, generate and commit it — CI fails outright without one.

**`✓ passed — 0 check(s)` is not a pass**, and neither is a stage whose command is `:` or `echo`.

**Do not reach step 5 with a red gate.** If it cannot be made green, stop: write the reason into `.claude/memory/tech-debt.md` and report `Onboarding incomplete — gate red` instead of the step 6 success block. Everything downstream (`/commit`, `/verify`, `/ship`, `/release`) is built on this script passing.

Fill `scripts/release.sh` the same way — only its deploy step may be a no-op. Then fill the two other project-facing scripts:
- **`scripts/healthcheck.sh`** — a `version_probe` per environment, from whatever the project exposes. Delete the `reference)` branch unless this project has a reference environment.
- **`scripts/dev.sh`** — the project's existing dev-run command, plus whatever migration and seed steps a test instance needs. `{{DEV_INFO}}` must be enough to drive the app blind: the exact URL or command and any test credentials, because the smoke-tester gets nothing else.

`scripts/gate-status.sh` and `scripts/criteria-check.sh` are plugin logic with no tokens — nothing to fill.

**Reconcile `testing-scope` with reality.** If the step 2 answer names a level the project has no directory or runner for, narrow the setting to what the gate actually runs — do not invent an integration directory and an npm script the project never asked for. Scaffold the missing level only if the user asks for it. Either way this **overrides an answer the user gave**, so say so in the step 6 report; silently recording a different value than the one they chose is worse than either option.

#### 3d. Reconcile the existing CI

If `.github/workflows/` already has CI, **do not leave it alone.** The `CLAUDE.md` you just installed asserts that the GitHub workflows call `scripts/ci.sh` — two independent definitions of "does this pass" make that false in an auto-loaded file, and the drift is invisible until something red merges.

Diff its steps against `ci.sh`, show the user the difference, and offer to replace the check steps with `- run: bash scripts/ci.sh full`, keeping the project's own triggers, matrix and any deploy/publish jobs (`templates/github/ci-{lang}.yml` is the shape to aim at). If the user declines, record the divergence in `.claude/memory/tech-debt.md` and say so in the report.

If there is no CI at all, offer `templates/github/ci-{language}.yml` — **substituting `{{CI_BRANCHES}}` with the whole bracketed list**: `[master]` for a `main-only` repo whose trunk is `master`, `[master, develop]` under git-flow. The token appears **twice** — on the `push` trigger and on `pull_request` — so fill both. Shipping it unsubstituted, or with `main` assumed, gives a workflow that never fires on a trunk push and says nothing about it — valid YAML, dead trigger.

#### 3e. Guidelines and the baseline gap check

**The scaffolder installed the whole library in 3a** — there is nothing to select, offer or decline, and no INDEX row to add. What this section is for is working out which guidelines describe *this* codebase, so you can **read** them before drafting the baseline tickets below and so the report tells the user which ones are now live for their project.

Detection hints: a map library (Leaflet/MapLibre/Mapbox) → `maps`; a charting library or hand-rolled SVG/canvas charts → `plots-graphs`; a Telegram lib (grammY/telegraf/python-telegram-bot) → `telegram-bots`; a web app with a PWA manifest / service worker → `web-app-pwa`; Railway → `railway`; a backend/service with domain/application/infrastructure layering or non-trivial business logic → `service-architecture`; a custom logging setup worth standardizing → `logging`; cron/scheduled jobs, retry logic, or a long-running process → `background-jobs`; any app bigger than a small script/tool → `app-baseline` (plus `changelog`, `ui-frontend` and `ai-integration` where they fit).

A guideline that does **not** match is still installed and still costs nothing — say so if the user asks why `telegram-bots.md` is sitting in their C++ repo: `INDEX.md` is read only when a task's subject matches a trigger, so an unmatched row is never followed.

**Check the developer-utility baseline and draft tickets for what's missing.** For anything bigger than a small script, check what `app-baseline.md` requires against what the project actually has — structured logging with adjustable levels, version visibility, an update mechanism, an in-app changelog, a way for Claude to smoke-test a live instance, and an access gate / API token auth where applicable. For each gap, create a backlog draft in `docs/specs/backlog/` (from `spec.md.template`; remove that directory's `.gitkeep` once a real spec lands in it) and tell the user it's there. These are debugging and development infrastructure, so they're worth doing before the next feature — say that, but don't block onboarding on them. A gap the user judges irrelevant gets dropped with a stated reason, not silently.

#### 3f. Railway (if deployed there)

If the project already deploys on Railway (a `railway.json`/`railway.toml` at the repo root, a Railway CI step, or the user confirms it):
- **Read `.claude/guidelines/railway.md`** — already installed with the rest of the library; it holds the scale-to-zero, region, URL and portability rules the steps below assume.
- **Watch paths** — so the workflow's constant docs/spec commits don't trigger redeploys:
  - No `railway.json`/`railway.toml`: offer `templates/configs/railway.json` at the repo root.
  - One exists without `build.watchPatterns`: offer to add the array, merging into the existing `build` object.
  - It already has them: leave them — a deliberate choice; just mention the docs/spec-commit rationale.
- Record the platform, the environment table, health check and required secrets in `docs/dev/deploy.md` — that file is where the deploy target lives; there is no `deploy` setting. If the app serves markdown/docs/tests content at runtime, drop the matching `!` line from `railway.json` and note the exception.

#### 3g. Other root files

- **`README.md`:** never overwrite one that exists — offer to append a short "Development" section linking to `CONTRIBUTING.md`. Create it from `templates/README.md.template` only if absent.
- **`CHANGELOG.md`:** the scaffolder creates it with only `## [Unreleased]`, which is wrong for a project already at a released version — its history silently absent. Seed it with a heading for the current version noting that history predates onboarding. Then check `git describe --tags --abbrev=0`: `/release` builds its entry from `git log <last tag>..HEAD`, and a repo with **no tags** fails there with "No names found, cannot describe anything". Offer to tag HEAD at the current version so `/release` has a base, or record the gap in `tech-debt.md`.
- **`.env.example`:** `docs/dev/setup.md` tells the reader to `cp .env.example .env`. If the project uses a `.env` and has none, generate one from the variables the analysis found (keys only, no values). If it *claims* a `.env` — a `.gitignore` entry, a README line — but no variable is discoverable in the code, ship a commented stub and record the discrepancy in `gotchas.md` rather than inventing keys. If it uses no `.env` at all, delete that section from `setup.md` rather than shipping a `cp` of a file that isn't there.

The skills, agents and hooks just installed under `.claude/` are picked up at **session start**, so they are not live in this session. Don't try to invoke one yet; the report in step 6 tells the user to restart.

### 4. GitHub Setup (if applicable)
Only run this step if the `github` setting is `yes` **and `git remote -v` resolves a GitHub remote.** Onboarding a local repo that will get its remote later is a common case for this skill, and `gh label create` fails outright with "no git remotes found".

- Create labels: `gh label create feature --force --color 0075ca` etc. (feature, bug, backlog, ready, in-progress, done — `--force` because defaults like `bug` already exist)

The issue templates are the scaffolder's job, not this step's — it creates them whenever `GITHUB_REPO` is not `no`.

With `github: yes` but no remote yet: create the issue templates, skip the labels, and tell the user to re-run the `gh label create` block once the remote exists.

### 5. Commit
```
git add -A
git status --short          # read it — every line must be something you meant to do
git commit -m "chore: install claude-workflow infrastructure"

# Now — and only now — prove the gate from a clean clone, which is what CI runs.
CLONE=$(mktemp -d)/vc
git clone . "$CLONE"
( cd "$CLONE" && npm ci && ./scripts/ci.sh full )   # or: uv sync --locked · cargo fetch
echo "clean-clone gate exit: $?"
rm -rf "$CLONE"
```

**The clone must come after the commit.** A clone of an uncommitted tree has no `scripts/` at all, so the check silently passes on a project that has nothing to run — the one guard against "green locally, red in CI" becomes a no-op. If it fails, amend or add a follow-up commit; do not reach step 6 on a red clone.

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

Gate: ci.sh fast exit {0} — {N} check(s)   ·   clean clone: exit {0} — {N} check(s)
Existing CLAUDE.md content moved to: {file → what went there, per item}
Inbound references repaired: {file:line → new target, or none}
Manifest/dependency changes: {what you added to package.json et al, and why — or none}
CI reconciliation: {workflow now calls ci.sh | divergence recorded in tech-debt.md}
Testing scope: {as you answered | narrowed to {X} because {reason}}
Guidelines installed: {list}
Baseline gaps drafted: {IDs}  ·  dropped: {gap — reason}
VISION.md: {drafted from the codebase — confirm before the first /plan}
Trunk branch: {name}  ·  {tagged v{x.y.z} so /release has a base | no tags — recorded in tech-debt.md}

Next steps:

  /draft feature "title"   to add first items manually
  /workflow-update         to update to latest version later

→ Restart your Claude Code session now.
  Hooks, status line, and all skills are fully active only after a fresh
  session start. Close this session and reopen it in the project directory.
```
