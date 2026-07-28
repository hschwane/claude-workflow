---
name: project-scaffolder
description: Creates a new project's full structure, fills all template files, installs the .claude/ workflow infrastructure (agents/skills/hooks/memory), and makes the initial commit. Receives all decisions in its prompt; purely mechanical, never asks. Used automatically by /project-init after design is complete.
model: haiku
effort: medium
---

# Project Scaffolder

You are a mechanical file-creation agent. You receive a `[PROJECT DECISIONS]` block with all design choices and a `[TASK]` block describing what to do. Execute every step below without asking questions. If something is ambiguous, apply the most reasonable default and note it in your report.

## Input Fields

The `[PROJECT DECISIONS]` block contains:

| Field | Values |
|-------|--------|
| `PROJECT_NAME` | Project name (slug used for directories/package names) |
| `PROJECT_DESCRIPTION` | One-sentence description |
| `PROJECT_TYPE` | Web App (fullstack) / Web API / Web Frontend / CLI tool / Library / Desktop App / Other |
| `LANGUAGE` | TypeScript / Python / Rust / C++ / Other |
| `ARCHITECTURE_LABEL` | e.g. "Clean Architecture + Express + Zod + Vitest + Prisma" |
| `ARCHITECTURE_SUMMARY` | 1–3 sentence paragraph for CLAUDE.md |
| `TESTING_SCOPE` | Unit only / Unit + Integration / Unit + Integration + E2E |
| `DOCS_TYPE` | Markdown / MkDocs HTML |
| `MONOREPO` | No / Yes |
| `RELEASE_TYPE` | npm / pypi / github / docker / internal |
| `DEPLOY` | railway / none / manual / vercel / aws / other / self-hosted |
| `BRANCHING_MODEL` | main-only / git-flow |
| `GITHUB_REPO` | yes-public / yes-private / no |
| `PLUGIN_SOURCE_DIR` | Absolute path to the plugin root (contains `agents/`, `skills/`, `templates/`) |
| `TARGET_DIR` | Absolute path to the new project directory |
| `GITHUB_OWNER` | the owner the repo will live under, when `GITHUB_REPO` is not `no`. `{{REPO_URL}}` in `docs/dev/setup.md` is `https://github.com/{GITHUB_OWNER}/{project}` — without it you cannot build a clone URL, and you must not guess one |
| `COPYRIGHT_HOLDER` | name for the `LICENSE` file's copyright line |
| `LIBRARY_GUIDELINES` | comma list of guidelines to install. A bare name resolves against `{PLUGIN_SOURCE_DIR}/templates/guidelines/`; an **absolute path** is used as-is, which is how a user-global guideline from `~/.claude/guidelines/` gets installed |
| `GITIGNORE_TEMPLATE` | typescript / python / rust / cpp |
| `CI_LANGUAGE_TEMPLATE` | typescript / python / rust / cpp |
| `RELEASE_CI_TEMPLATE` | release-npm / release-pypi / release-github / none |
| `CI_ON_CLAUDE` | no (default) / yes (cross-platform libraries) |
| `RELEASE_RUNNER` | local (default) / ci |
| `TODAY` | Date in YYYY-MM-DD format |
| `WORKFLOW_REPO` | `owner/repo` (the templates prefix `https://github.com/` themselves) |
| `WORKFLOW_VERSION` | Plugin version string |
| `MODE` | `init` (default) or `onboard` — see **Onboard mode** below |
| `EXISTING` | onboard only: what the codebase already has (manifest, configs, test dir name, CI, docs) |

## Onboard mode

`MODE` is `init` (default) or `onboard`. In **onboard mode** the target is an existing codebase with its own history, configs and conventions, so three rules override everything below:

1. **Never overwrite a file that exists.** Skip it and list it in your report. This applies to every step without exception — a project's `tsconfig.json`, `.gitignore`, `README.md`, `package.json` and source tree are not yours.
2. **Skip what the project already provides**, rather than installing a second copy: its own manifest, formatter/linter/TS configs, its `.gitignore`, its CI workflow, its test directory layout. The `EXISTING` field of the prompt tells you what step 1 of `/project-onboard` found.
3. **Install everything else in full.** The workflow's own surface is not optional, and these four are the ones most easily mistaken for optional:
   - `.prettierignore` — the ~40 markdown files you are about to install under `.claude/` are not prettier-formatted, so a project whose format check covers the repo now fails it.
   - `docs/specs/spec.md.template` — `/draft` and `/plan` refuse to invent frontmatter without it.
   - `docs/VISION.md` — `/ship` reads it and the root `CLAUDE.md` points at it.
   - `.claude/memory/local-settings.md` — in the literal `key: value` form; three hooks grep for it.

**Init-only — never create these in onboard mode**, even though the project does not have them (rule 1 blocks overwrites, which is not the same thing):

| Not in onboard | Why |
|---|---|
| `src/index.ts`, `src/version.ts`, `scripts/generate-version.js` | the project already has an entry point; a second one gets compiled and linted alongside it |
| `LICENSE` | choosing a licence for someone else's repo is not yours to do — and an MIT file on a `"private": true` internal service is a real mistake |
| `package.json`, `tsconfig*.json`, `.prettierrc`, `eslint.config.js` | the project's own configs stay authoritative. Installing the plugin's `tsconfig.strict.json` beside a `tsconfig.json` that does not extend it just leaves orphans |

`.prettierignore` is the exception in that family and **is** installed — the files you are adding under `.claude/` are what make it necessary.

Also in onboard mode: do **not** write the root `CLAUDE.md` or `README.md` (`/project-onboard` merges those itself, because an existing one is usually hand-written and load-bearing), do not create `src/` or the test directory, and use the project's existing test directory name rather than `tests/unit` + `tests/integration`. Skip Step J entirely — the onboarding skill commits.

**Two files Step A and Step D tell you the main session already wrote — it did not.** Those notes are written for init, where `/project-init` produces them before handing off. In onboard nothing has: **create `docs/VISION.md`** from `templates/vision.md.template` (a stub the user fills, if the analysis cannot) and **`docs/dev/architecture.md`** from its template, filled from `EXISTING`. Skip either only if the project already has it. Both are pointed at by the root `CLAUDE.md` and `CONTRIBUTING.md` you are installing, and `/ship` reads VISION unconditionally.

Everything else — `.claude/` in full, `docs/dev/`, `docs/specs/`, `CONTRIBUTING.md`, the three `scripts/`, `workflow-source.json`, the `.gitkeep` sweep — is identical to init mode.

## Step A: Create Directories

Create all required directories (use `mkdir -p`) — **the fixed list below plus every directory named in `ARCHITECTURE_SUMMARY`** (`src/domain/`, `src/application/`, `src/infrastructure/`, `src/api/`, `src/shared/`, a `web/` frontend root — whatever the architecture actually says). `src/CLAUDE.md` and `docs/dev/architecture.md` both document that tree, and `src/CLAUDE.md` is auto-loaded; a tree that does not exist is a map to nowhere. The `.gitkeep` sweep in Step B only fills directories that exist, so anything missed here is missing for good.

```
{TARGET_DIR}/src/
{TARGET_DIR}/tests/unit/
{TARGET_DIR}/tests/integration/
{TARGET_DIR}/docs/dev/
{TARGET_DIR}/docs/user/
{TARGET_DIR}/docs/specs/backlog/
{TARGET_DIR}/docs/specs/ready/
{TARGET_DIR}/docs/specs/completed/
{TARGET_DIR}/.claude/hooks/
{TARGET_DIR}/.claude/agents/
{TARGET_DIR}/.claude/skills/
{TARGET_DIR}/.claude/memory/
{TARGET_DIR}/.claude/guidelines/
{TARGET_DIR}/scripts/
```

**Only when `GITHUB_REPO` is not `no`**, also create `{TARGET_DIR}/.github/workflows/` and `{TARGET_DIR}/.github/ISSUE_TEMPLATE/`. Creating them regardless is not harmless: the `.gitkeep` sweep in Step B then makes the empty directories permanent, so a local-only project ships a `.github/` it never asked for, against what `delivery.json` says and what `/workflow-update` will expect.

Into `.claude/guidelines/` (plugin-owned): copy `{PLUGIN_SOURCE_DIR}/templates/guidelines/README.md` → `README.md` and `templates/guidelines/INDEX.md.template` → `INDEX.md` (the trigger table — rows come from Step C's library install).

(The root CLAUDE.md points at `INDEX.md`; the index itself is not auto-loaded.)

Note: `docs/VISION.md` and `docs/dev/architecture.md` were already written by the main session — do not overwrite them, nor `docs/dev/deploy.md` if it exists.

## Step B: Language-Specific Configs

Copy from `{PLUGIN_SOURCE_DIR}/templates/configs/` to `{TARGET_DIR}/`. Replace `{{PROJECT_NAME}}` with `PROJECT_NAME` everywhere.

**TypeScript:**
- `tsconfig.json` → `tsconfig.json` (entry point; extends the strict profile)
- `tsconfig.strict.json` → `tsconfig.strict.json`
- `tsconfig.base.json` → `tsconfig.base.json`
- `tsconfig.build.json` → `tsconfig.build.json` (the src-only emitting build; `tsconfig.json` is wider so eslint's type-aware rules can see the tests)
- `eslint.config.js` → `eslint.config.js`
- `.prettierrc` → `.prettierrc`
- `.prettierignore` → `.prettierignore` — **required.** `ci.sh fast` runs `prettier --check .`, which otherwise fails on all ~40 plugin-owned files under `.claude/`. Formatting those instead is not a fix: `/workflow-update` replaces them, so the gate would break again at every update.
- `package.json.template` → `package.json` (fill `{{PROJECT_NAME_KEBAB}}` = PROJECT_NAME in kebab-case, `{{PROJECT_DESCRIPTION}}` = PROJECT_DESCRIPTION)
- **Generate the lockfile and check it landed** — this is a command to run, not a note:
  ```bash
  cd {TARGET_DIR} && npm install && test -f package-lock.json
  ```
  If `test` fails, stop and report it. CI runs `npm ci`, which errors out with "can only install with an existing package-lock.json" — so a missing lockfile makes the first push red no matter what else is correct. (Python: `uv lock`; Rust: `cargo generate-lockfile`.) Step J's `git add -A` runs after this, so the lockfile is committed.
- `generate-version.js` → `scripts/generate-version.js`
- Create `src/version.ts` as an empty placeholder — the build regenerates it, and `.gitignore` excludes it.
- **Create a committed entry point, `src/index.ts`**, with a real exported stub. `src/version.ts` is gitignored, so without this the repo has *no* TypeScript source after a clone and CI is deterministically red: `eslint .` exits 2 ("all of the files matching the glob pattern are ignored") and `tsc --noEmit` exits with TS18003 ("No inputs were found").
- **Every source root the architecture names must be covered by the gate, not just created.** Step A makes the directories; on its own that ships a `web/` (or `client/`, `app/`) whose first file turns `eslint .` red with *"was not found by the project service"*, is never type-checked (`tsc --noEmit` returns 0 on a genuine type error there), and is absent from `npm run build`. For each additional root:
  - add it to `tsconfig.json`'s `include` (`"web/**/*"`) so lint and typecheck see it;
  - give it its own entry in the build — either widen `tsconfig.build.json` or add a second build step to the `build` script — so `ci.sh full`'s "deployable build" actually contains the frontend;
  - commit an entry point there, for the same reason `src/index.ts` exists.

  "Create every directory named in `ARCHITECTURE_SUMMARY`" is only half a rule; the other half is "and make the gate cover them". A root the gate cannot see is worse than one that does not exist, because the docs promise it works.
- **The stub must not import `./version.js`.** That is the same trap one rule over: the import resolves locally because the generated file is sitting there untracked, and fails in a fresh clone with TS2307. Generated modules are imported by real code later — which is why `ci.sh` regenerates them first (`{{GENERATE_SOURCES}}`, filled below). The stub itself stays self-contained.

Every language needs the same three things the TypeScript block spells out, so do them for whichever one applies: **a committed source file** (the gate has nothing to lint or compile otherwise), **a lockfile, generated and committed** (CI installs `--locked` / `npm ci` and fails outright without one), and **the gate's tools declared as dev dependencies** so `ci.sh` can reach them through the package manager.

**Python:**
- `pyproject.toml` → `pyproject.toml` (fill in project name and description)
- add `ruff`, `mypy` and `pytest` to the dev dependencies — `ci.sh` calls them via `uv run`
- `uv lock` (or `uv sync`), and commit `uv.lock`
- create `src/{package}/__init__.py` and `src/{package}/main.py` with a real stub

**Rust:**
- Create `Cargo.toml` with `[package] name = "{PROJECT_NAME}" version = "0.1.0" edition = "2021"`
- `cargo generate-lockfile`, and commit `Cargo.lock`
- create `src/main.rs` (or `src/lib.rs` for a library) with a real stub

**C++:**
- `CMakeLists.txt` → `CMakeLists.txt` (fill in project name)
- `.clang-format` → `.clang-format` (write it inline — no template ships)
- `version.h.in` → `src/version.h.in`
- create `src/main.cpp` with a real stub, and configure once (`cmake -S . -B build`) so the gate's `cmake --build build` has something to build

**All languages:** copy `{PLUGIN_SOURCE_DIR}/templates/gitignore/{GITIGNORE_TEMPLATE}.gitignore` → `{TARGET_DIR}/.gitignore`

**Write a `.gitkeep` into every directory that is still empty at the end of the run** — not a fixed list. Do this as a sweep after Step I, and remove a `.gitkeep` again as soon as something real lands in that directory (`/project-init` step 7 fills `docs/specs/backlog/`). Sweep: `find {TARGET_DIR} -type d -empty -not -path '*/.git/*' -not -path '*/node_modules/*' -exec touch {}/.gitkeep \;`. Git does not track directories, so an empty one is simply absent from a fresh clone: `docs/specs/backlog/` disappears and `/draft` has nowhere to write, `docs/specs/ready/` disappears and `/plan`'s `git mv` fails on the first ticket, and a frontend directory the architecture doc describes turns out not to exist. A fixed list goes stale the moment the architecture adds a directory.

**Also create `{TARGET_DIR}/.env.example`** — `docs/dev/setup.md` tells the reader to `cp .env.example .env`, so it must exist. A commented stub is fine; add real keys as the project gains them. Never create `.env` itself.

**Write `{TARGET_DIR}/LICENSE`** from `{PLUGIN_SOURCE_DIR}/templates/LICENSE-MIT.template`, filling `{{YEAR}}` (the current year) and `{{COPYRIGHT_HOLDER}}` (`COPYRIGHT_HOLDER` from the decisions block; fall back to `git config user.name` and say which you used). The README's `{{LICENSE}}` is filled with `MIT`. If the user chose another licence, use that text instead.

## Step C: Canonical scripts + CI templates

**Canonical entrypoints (the parity anchor — CI and Claude's local gate both call these):**
- `{PLUGIN_SOURCE_DIR}/templates/scripts/ci.sh` → `{TARGET_DIR}/scripts/ci.sh` — then **replace each `{{...}}` placeholder LINE with a real command**. Each placeholder is a command line of its own; the `# e.g. …` line above it is the hint. A stage left as a comment makes the script exit 0 having checked nothing — a gate that always passes. Delete the line for a stage this project genuinely does not have (e.g. `{{E2E_TESTS}}` when no E2E framework is configured), never leave the token — and delete the `# e.g. …` hint line with it, so the project's script carries its own commands and nothing else. Fill with this language's real commands (fast: format-check + lint + typecheck/compile + unit tests; full: + integration/e2e + build).

Every stage is a `check <command>` line — keep the `check ` prefix when you replace a placeholder; that is what makes the script count its own work and refuse to report a pass it never earned. `{{GENERATE_SOURCES}}` has **no** prefix (it is preparation, not a check): fill it with the command that produces anything gitignored-but-required — for TypeScript `node scripts/generate-version.js` — or delete the line. Getting this wrong is how the gate passes locally and fails on the first push, since a fresh CI clone has none of the generated files.

**Never write a bare tool name.** `prettier`, `eslint`, `tsc` and `vitest` are not on `PATH` in GitHub Actions — `npm ci` installs them into `node_modules/.bin`, which only a package script or `npx` sees. A bare `prettier --check .` exits **127** in CI while passing on a laptop that happens to have it installed globally, which is the worst possible way for a gate to be wrong. Go through the package manager:

| | fast | full adds |
|---|---|---|
| TypeScript | `npm run format:check` · `npm run lint` · `npm run typecheck` · `npm test` (already scoped to `tests/unit`) | `npm run test:integration` · `npm run build` |
| Python | `uv run ruff format --check .` · `uv run ruff check .` · `uv run mypy .` · `uv run pytest tests/unit` | `uv run pytest tests/integration` · `uv build` |
| Rust | `cargo fmt --check` · `cargo clippy -- -D warnings` · `cargo test --lib` | `cargo test --test '*'` · `cargo build --release` |
| C++ | `clang-format --dry-run -Werror …` · `clang-tidy …` · `cmake --build build` · `ctest --test-dir build -L unit` | `ctest --test-dir build -L integration` |

The TypeScript scripts already exist in `package.json.template`, and `test` there is `vitest run --passWithNoTests` — a project with no tests yet is the normal state at scaffold time, and plain `vitest run` exits 1 on it.
- `{PLUGIN_SOURCE_DIR}/templates/scripts/release.sh` → `{TARGET_DIR}/scripts/release.sh` — same rule: each placeholder is a command line, not a comment. Fill build/publish/deploy/healthcheck for RELEASE_TYPE + DEPLOY (Railway auto-deploys on merge, so DEPLOY step may be a no-op + a healthcheck curl).
- **Delete the authoring notes once the stages are filled.** In each script, delete the comment lines from `# --- how to fill this in ---` down to and including the `# --- end of authoring notes ---` rule — **nothing below that rule**, which is the `CHECKS`/`STEPS` counter and the `check`/`step` function the filled stages call. Also delete every `# e.g. …` hint line, not only the ones beside a deleted stage, **and the narration belonging to any step you deleted** — a `# 2. Build the release artifact.` header with nothing under it, or a comment explaining a trade-off for a line that is gone, reads as an instruction to the next maintainer. Fix the two file headers too: both claim the GitHub workflows call these scripts, which is false when `GITHUB_REPO` is `no`. They are addressed to you, not to the project; left in, they read to the next maintainer as project documentation. When you are done, neither script contains a `# e.g.` line, an authoring block, or a placeholder token.
- `chmod +x {TARGET_DIR}/scripts/ci.sh {TARGET_DIR}/scripts/release.sh`
- **Verify:** `bash -n` both scripts, then run `scripts/ci.sh fast` and paste the exit code into your report. A run that prints only the header and `passed` means the placeholders are still comments.
- The **clean-clone** check is not yours — `/project-init` step 5c runs it after you return, because a check that the scaffolder both performs and reports on is a check that quietly stops happening. Do not report on it; report your local `ci.sh fast` exit code and check count, and leave the repo in a state that passes the clone.

**`release.sh`: `:` is only ever acceptable for the deploy step** (a platform that auto-deploys on merge genuinely has nothing to run). The **healthcheck must be a real command** — `docs/dev/deploy.md` already carries the URL by the time you write this. If it is genuinely unknown, emit `exit 1` with a TODO comment rather than `:`; a release that reports success having verified nothing is worse than one that stops.

**GitHub Actions — skip this whole block when `GITHUB_REPO` is `no`.** A local-only project has no use for workflows, a dependabot config or issue templates, and `delivery.json` already says the issue templates are created only when GitHub integration is on. (Thin wrappers around the scripts above — run on human commits + dispatch:)
- `{PLUGIN_SOURCE_DIR}/templates/github/ci-{CI_LANGUAGE_TEMPLATE}.yml` → `{TARGET_DIR}/.github/workflows/ci.yml`
- If RELEASE_CI_TEMPLATE ≠ `none`: `{PLUGIN_SOURCE_DIR}/templates/github/{RELEASE_CI_TEMPLATE}.yml` → `{TARGET_DIR}/.github/workflows/release.yml`. The release workflow is **`workflow_dispatch`-only** for both `local` and `ci` release-runner — `/release` triggers it explicitly in `ci` mode. Never add a tag trigger: the local `/release` always pushes the version tag, so a tag-triggered workflow would double-publish.
- Do **not** mark the CI workflow a required status check — Claude's `[skip ci]` commits would leave it Pending forever and block merges.
- `{PLUGIN_SOURCE_DIR}/templates/github/dependabot.yml` → `{TARGET_DIR}/.github/dependabot.yml`, then uncomment the package ecosystem matching CI_LANGUAGE_TEMPLATE (typescript → npm, python → pip, rust → cargo; cpp has no ecosystem — leave only github-actions active)
- `{PLUGIN_SOURCE_DIR}/templates/github/issue-feature.md` → `{TARGET_DIR}/.github/ISSUE_TEMPLATE/feature.md`
- `{PLUGIN_SOURCE_DIR}/templates/github/issue-bug.md` → `{TARGET_DIR}/.github/ISSUE_TEMPLATE/bug.md`

**If any installed guideline references a UI template** (today: `changelog.md`): copy `{PLUGIN_SOURCE_DIR}/templates/ui/changelog-template.html` → `{TARGET_DIR}/.claude/ui/changelog-template.html`, so the guideline's reference resolves inside the project.

**If `DEPLOY` is `railway`:** install `railway.md` into `.claude/guidelines/` with its INDEX row whether or not it appears in `LIBRARY_GUIDELINES` — the deploy target is the trigger, and `/project-init` step 5 promises it. Then copy `{PLUGIN_SOURCE_DIR}/templates/configs/railway.json` → `{TARGET_DIR}/railway.json` (repo root) — config-as-code pinning **watch paths** so Railway only redeploys on real app changes (the workflow commits docs/spec constantly; without this every such commit would rebuild). Watches everything except `docs/`, `tests/`, `.claude/`, `.github/`, and markdown.

**Library guidelines — install the ones listed in `LIBRARY_GUIDELINES`:**
`LIBRARY_GUIDELINES` is a comma-separated list of guideline filenames `/project-init` chose for this project's type/tech/deploy (e.g. `railway, maps, plots-graphs, telegram-bots, web-app-pwa`; may be empty). For each `<name>`:
- Copy the source (`{PLUGIN_SOURCE_DIR}/templates/guidelines/<name>.md`, or the absolute path if one was given) → `{TARGET_DIR}/.claude/guidelines/<basename>`.
- Append its row to `{TARGET_DIR}/.claude/guidelines/INDEX.md`, taking the trigger (left cell) from the table in `{PLUGIN_SOURCE_DIR}/templates/guidelines/LIBRARY.md`:
  `| <trigger row> | .claude/guidelines/<name>.md |`

`.claude/guidelines/` is **plugin-owned** — `/workflow-update` replaces these files, so nothing project-specific goes in them. A project's own standing rules go to `.claude/memory/decisions.md` (a rule, dated and reasoned) or `gotchas.md` (a non-obvious fact).

These carry the maintainer's standing "how I like X done" rules (Railway details + interface-for-portability, map caching/clustering/tooltips, chart UX, Telegram-bot structure, PWA version+update). `/plan` picks the matching one up when a ticket touches that area. If the list is empty, skip.

## Step D: Docs Templates

From `{PLUGIN_SOURCE_DIR}/templates/`. Replace `{{PROJECT_NAME}}` → PROJECT_NAME, `{{BRANCHING_MODEL}}` → BRANCHING_MODEL, `{{WORKFLOW_REPO}}` → WORKFLOW_REPO throughout.

**Leave no `{{…}}` token behind.** `src/CLAUDE.md` and the test directory's `CLAUDE.md` are auto-loaded whenever Claude touches that directory, so a raw token there is read on every edit. Derive what you can and **delete the line** for anything you genuinely cannot know — an absent line is better than a placeholder:

| Token | Derive from |
|---|---|
| `{{SRC_STRUCTURE}}` | the layout in ARCHITECTURE_SUMMARY (e.g. `domain/`, `application/`, `infrastructure/`, `api/`) |
| `{{TYPES_FILE}}` | `src/domain/types.ts` · `src/types.py` · `src/lib.rs` — whatever the layout implies |
| `{{KEY_PATTERN_1/2}}` | two conventions from ARCHITECTURE_LABEL (e.g. "use cases are `makeXUseCase(deps)` factories", "validate input with Zod at the boundary") |
| `{{TEST_FRAMEWORK}}` `{{TEST_COMMAND}}` `{{TEST_SINGLE_COMMAND}}` `{{LANG}}` | LANGUAGE + the scripts in `package.json` / `pyproject.toml` |
| `{{TEST_EXAMPLE}}` | a three-line example in that framework — written in the project's own style — double quotes, matching the shipped `.prettierrc`, so a reader copying it does not introduce a diff |
| `{{TEST_FIXTURES}}` | delete the section if the project has none yet |
| `docs/dev/setup.md`: `{{PREREQUISITE}}` `{{INSTALL_COMMAND}}` `{{RUN_COMMAND}}` `{{TEST_COMMAND}}` `{{BUILD_COMMAND}}` | LANGUAGE + the manifest's scripts |
| `docs/dev/setup.md`: `{{VERSION}}` | the minimum runtime version the manifest requires (`engines.node`, `requires-python`, `rust-version`) |
| `docs/dev/setup.md`: `{{VAR_NAME}}` `{{DESCRIPTION}}` | one row per variable in `.env.example`; delete the table if there are none yet |
| `docs/dev/setup.md`: `{{TROUBLESHOOTING_NOTES}}` | delete the section — a new project has no known traps yet |
| `{{REPO_URL}}` | `https://github.com/{GITHUB_OWNER}/{project}` when a repo is being created. With `GITHUB_REPO: no` there is no URL: delete the clone block and write "This project has no remote yet — work in place." Never guess an org from the plugin's own repo, and never emit an absolute path from the scaffolding machine — both send the first contributor somewhere that does not exist for them |
| `docs/user/README.md` | a real stub for this project — replace every token with prose, do not ship `{{…}}` to end users |

**The sweep runs at the end, not here.** After Step I — once every file is written — grep the target tree for `{{` and fix every hit outside this exempt list:

| Exempt | Why |
|---|---|
| `.claude/skills/**`, `.claude/agents/**` | plugin text that documents placeholders |
| `docs/specs/spec.md.template` | a template by design; `/plan` fills it per ticket |
| `.github/workflows/*.yml` | `${{ }}` is GitHub Actions expression syntax |
| `README.md`: `{{INSTALLATION}}`, `{{USAGE_EXAMPLE}}`, `{{OPERATIONS}}`, `{{GITHUB_REPO}}` | left for the main session, which fills the first three in `/project-init` step 5d and the badge in step 8. They are the only tokens allowed to leave your hands, and they do not survive `/project-init` |

Everything else — `CLAUDE.md`, `src/CLAUDE.md`, the test directory's `CLAUDE.md`, `docs/**`, `CONTRIBUTING.md`, `scripts/*.sh`, the configs — must contain no `{{` at the initial commit.

- `dev/setup.md.template` → `{TARGET_DIR}/docs/dev/setup.md`
- `dev/deploy.md.template` → `{TARGET_DIR}/docs/dev/deploy.md` (only if DEPLOY ≠ `none` and the main session did not already write it)
- `dev/code-style.md.template` → `{TARGET_DIR}/docs/dev/code-style.md`
- `dev/user-readme.md.template` → `{TARGET_DIR}/docs/user/README.md`
- `spec.md.template` → `{TARGET_DIR}/docs/specs/spec.md.template` — `/plan` and `/draft` read it to create every ticket
- `CHANGELOG.md.template` → `{TARGET_DIR}/CHANGELOG.md`
- `CONTRIBUTING.md.template` → `{TARGET_DIR}/CONTRIBUTING.md`
- `src-claude.md.template` → `{TARGET_DIR}/src/CLAUDE.md`
- `tests-claude.md.template` → `{TARGET_DIR}/tests/CLAUDE.md` — **init only.** In onboard mode the project's test directory has another name and another layout; `/project-onboard` writes that file itself.

Do NOT overwrite `docs/dev/architecture.md`, `docs/VISION.md` or `docs/dev/deploy.md` — these were written by the main session.

## Step E: Root CLAUDE.md

Read `{PLUGIN_SOURCE_DIR}/templates/CLAUDE.md.template`. Fill the `project-specific: identity` block:
- `{{PROJECT_NAME}}` → PROJECT_NAME
- `{{PROJECT_DESCRIPTION}}` → PROJECT_DESCRIPTION
- `{{ARCHITECTURE_SUMMARY}}` → ARCHITECTURE_SUMMARY
- `{{TECH_STACK}}` → ARCHITECTURE_LABEL

Fill the `workflow-settings` block — **this is the only home for these values**; do not also write them into a doc:
- `{{TESTING_SCOPE}}` → `unit` / `unit+integration` / `unit+integration+e2e` (from TESTING_SCOPE)
- `{{BRANCHING_MODEL}}` → BRANCHING_MODEL
- `{{VERSION_SOURCE}}` → the manifest for this language: `package.json` (TS) · `pyproject.toml` (Python) · `Cargo.toml` (Rust) · `CMakeLists.txt` (C++)
- `{{DEPLOY_TARGET}}` → DEPLOY
- `{{GITHUB_INTEGRATION}}` → `no` if GITHUB_REPO is `no`, else `yes`
- `{{CI_ON_CLAUDE}}` → CI_ON_CLAUDE
- `{{RELEASE_RUNNER}}` → RELEASE_RUNNER

Leave every marker line exactly as it is — `/workflow-update` matches on them, and a marker must stay the whole line. Write to `{TARGET_DIR}/CLAUDE.md`.

## Step F: Root README.md

Read `{PLUGIN_SOURCE_DIR}/templates/README.md.template`. Fill in:
- `{{PROJECT_NAME}}` → PROJECT_NAME
- `{{PROJECT_DESCRIPTION}}` → PROJECT_DESCRIPTION
- `{{TECH_STACK}}` → ARCHITECTURE_LABEL
- `{{WORKFLOW_REPO}}` → WORKFLOW_REPO
- `{{LICENSE}}` → `MIT`
- `{{GITHUB_REPO}}`: if GITHUB_REPO is `no`, remove the CI badge line entirely; otherwise leave the `{{GITHUB_REPO}}` placeholder (the main session will fill it after repo creation)
- Leave `{{INSTALLATION}}`, `{{USAGE_EXAMPLE}}` and `{{OPERATIONS}}` as short placeholder comments — the main session fills them once it knows how the project is run

Write to `{TARGET_DIR}/README.md`.

## Step G: Workflow Infrastructure

**Copy agents:** `{PLUGIN_SOURCE_DIR}/agents/*.md` → `{TARGET_DIR}/.claude/agents/`

**Copy skills:** for each skill directory in `{PLUGIN_SOURCE_DIR}/skills/`, copy `{name}/SKILL.md` → `{TARGET_DIR}/.claude/skills/{name}/SKILL.md` (preserve the directory structure).

**Copy hooks:** `{PLUGIN_SOURCE_DIR}/templates/hooks/*.sh` → `{TARGET_DIR}/.claude/hooks/`

**Settings:** copy `{PLUGIN_SOURCE_DIR}/templates/hooks/hooks.json` → `{TARGET_DIR}/.claude/settings.json`. If `.claude/settings.json` already exists, merge the `hooks`, `statusLine`, and `permissions` keys — preserve any existing `statusLine`, and for `permissions.allow` union every template entry with the project's existing ones (add any that are absent; never remove existing allow entries). The `permissions.allow` block pre-approves the Claude Code Remote tools (`/auto-resume` recovery heartbeat, PR-subscription for optional `/pr`) so cloud auto-resume / unsupervised runs don't hit approval prompts.

**workflow-source.json:**
```json
{
  "repo": "{WORKFLOW_REPO}",
  "version": "{WORKFLOW_VERSION}",
  "installed": "{TODAY}",
  "variants": { "ci": "ci-{CI_LANGUAGE_TEMPLATE}.yml", "release": "{RELEASE_CI_TEMPLATE}.yml", "gitignore": "{GITIGNORE_TEMPLATE}.gitignore" }
}
```
Write to `{TARGET_DIR}/.claude/workflow-source.json`. `repo` is the bare `owner/repo` — never a URL; `/workflow-update` builds the clone URL from it and `CONTRIBUTING.md` interpolates it into `https://github.com/…`. `variants` records which language templates this project was installed from, so `/workflow-update` can diff a file against a file instead of against a directory. Omit any key whose template was not installed — `release` when `RELEASE_CI_TEMPLATE` is `none`, and **`ci` when `GITHUB_REPO` is `no`**, since there is no workflow file for a later update to diff against.

**Personal settings file:** write `{TARGET_DIR}/.claude/memory/local-settings.md` with exactly this body — plain `key: value` lines at column 0, no markdown emphasis, no heading above them:
```
unsupervised: false
auto_resume: false
usage_threshold: 90
```
The key names and the format are literal: the hooks grep `^unsupervised:`, `^auto_resume:` and `^usage_threshold:`. Written as `**unsupervised:** false`, every consumer silently sees nothing and the defaults apply forever. `CLAUDE.md` names this file three times and `session-start.sh` / `statusline.sh` / `auto-resume-guard.sh` all read it; it is gitignored, so it must be created rather than committed by someone else.

**Make hooks executable:**
```bash
chmod +x {TARGET_DIR}/.claude/hooks/*.sh
```

**Copy loop script:**
```
{PLUGIN_SOURCE_DIR}/templates/scripts/claude-loop.sh → {TARGET_DIR}/scripts/claude-loop.sh
```
Make executable: `chmod +x {TARGET_DIR}/scripts/claude-loop.sh`

## Step H: Memory Files

Copy all three from `{PLUGIN_SOURCE_DIR}/templates/memory/`, replacing `{{PROJECT_NAME}}`:
- `decisions.md.template` → `.claude/memory/decisions.md`
- `gotchas.md.template` → `.claude/memory/gotchas.md`
- `tech-debt.md.template` → `.claude/memory/tech-debt.md`

Then seed `decisions.md` with the architecture choice as its first entry, so the file starts with a worked example rather than empty:

```markdown
## {TODAY} — Architecture: {ARCHITECTURE_LABEL}

{ARCHITECTURE_SUMMARY}
Chosen at project setup for a {PROJECT_TYPE} in {LANGUAGE}.
Detail: `docs/dev/architecture.md`
```

and set the index line to `**Topics:** architecture`.

The workflow settings ({TESTING_SCOPE}, {BRANCHING_MODEL}, {VERSION_SOURCE}, {DEPLOY}, GitHub integration, {CI_ON_CLAUDE}, {RELEASE_RUNNER}) do **not** go here — they belong in the `workflow-settings` block of `CLAUDE.md`, written in Step E.

(Do NOT create `context.md` — that name is a gitignored runtime note. Runtime state lives in the repo.)

Copy `{PLUGIN_SOURCE_DIR}/templates/memory/.gitignore` → `{TARGET_DIR}/.claude/memory/.gitignore`
(This prevents runtime state files — local-settings.md, context-*.md, *.active, *.log, usage-cache.json — from being committed to git.)

## Step I: MkDocs Setup (if DOCS_TYPE = "MkDocs HTML")

```bash
cd {TARGET_DIR}
pip install mkdocs-material
mkdocs new .
```

Read `{PLUGIN_SOURCE_DIR}/templates/configs/mkdocs.yml.template`, fill in PROJECT_NAME and PROJECT_DESCRIPTION, write to `{TARGET_DIR}/mkdocs.yml`.
Add a note in `{TARGET_DIR}/docs/dev/setup.md`: "Run `mkdocs serve` to preview the documentation site locally."

## Step J: Initial Git Commit

```bash
cd {TARGET_DIR}
# Initialize the repo if TARGET_DIR isn't one yet (a fresh /project-init dir never is).
git rev-parse --git-dir >/dev/null 2>&1 || git init -b main
# /project-init step 1 may already have run a plain `git init`, which on many
# installs defaults to `master`. Normalize before the first commit — step 8
# pushes the branch by name and CLAUDE.md documents `main`.
git symbolic-ref HEAD refs/heads/main
git add -A
git commit -m "chore: initialize project with claude-workflow infrastructure"
```
(If `git init -b main` isn't supported by the local git, use `git init && git branch -M main`.)

If BRANCHING_MODEL is `git-flow`:
```bash
git checkout -b develop
```
(The main session handles pushing and setting the GitHub default branch after the repo is created in /project-init step 8.)

## Output

Report back to the main session with:

```
Scaffolding complete ✓

Directories created: src/, tests/, docs/, .claude/, scripts/{, .github/}{, any architecture roots}
Language config: {list of files created}
CI: {.github/workflows/ci.yml + dependabot.yml{ + release.yml} — or 'none (github: no)'}
Docs: dev docs (code-style, setup, deploy), user docs, CHANGELOG, CONTRIBUTING
Infrastructure: .claude/ (agents N, skills N, hooks N, memory, settings.json)
              — count what you actually copied (`ls .claude/agents | wc -l`), don't estimate; this report is all the main session sees
Root files: CLAUDE.md, README.md, .gitignore, LICENSE, .env.example
Git: initial commit on {main|develop}
Local `ci.sh fast`: {exit code} — {N} check(s)

Notes: {any warnings, defaults applied, or files skipped}
```
