# claude-workflow

A professional, reusable AI-assisted software development workflow for Claude Code. Covers the full lifecycle from idea to release.

## What It Does

```
/draft → /plan → /implement → /verify → merge → /release  (or just /ship)
```

An idea enters the backlog as a one-liner, gets planned into a spec with observable acceptance criteria, is implemented subtask-by-subtask with tests, is verified by running it, merges locally, and ships with a semver release — each step is one command, or `/ship` runs the whole chain.

## Quick Start

**Install in one prompt** — paste this into any Claude Code session (web app, VS Code extension, or console):

```
Clone https://github.com/hschwane/claude-workflow into /tmp/claude-workflow-bootstrap, then read /tmp/claude-workflow-bootstrap/bootstrap.md and follow the instructions.
```

Claude will ask whether you want a new project or to onboard an existing one, then run the full setup automatically.

### Manual setup (if you prefer `--plugin-dir`)

**New project:**
```bash
cd ~/my-projects
claude --plugin-dir /path/to/claude-workflow
```
Then in Claude Code:
```
/project-init
```

**Existing project:**
```bash
cd my-existing-project
claude --plugin-dir /path/to/claude-workflow
```
Then:
```
/project-onboard
```

After onboarding, the plugin is embedded in `.claude/` — just run `claude` normally.

## Skills

Skills are the user-facing commands. Setup skills:

| Skill | What it does |
|-------|--------------|
| `/project-init` | Create a new project from scratch: vision workshop, architecture decision, configs, CI, GitHub repo, hooks, initial backlog |
| `/project-onboard` | Install the workflow into an existing project without disrupting it (analyzes the codebase first via `code-explorer`) |
| `/workflow-update` | Pull a newer plugin version into the project; overwrites system files, never touches project files |

The development lifecycle:

| Skill | What it does |
|-------|--------------|
| `/draft feature\|bug "title"` | Capture a raw idea as a minimal spec in `docs/specs/backlog/` (+ GitHub issue). Deliberately no planning — capturing must be cheap |
| `/plan FEAT-001 [FEAT-002 …]` | Turn draft(s) into ready spec(s) in one light pass: goal, **observable acceptance criteria**, approach + interfaces, subtasks. Surfaces open questions (batched up front for multiple IDs), defaults to in-scope. Uses `code-explorer` for codebase context |
| `/implement FEAT-001` | For each subtask: write code + its tests, run the fast gate (`ci.sh fast` via `runner`), commit green, tick the box. Then runs `/verify`. State is the repo (spec boxes + git log) |
| `/verify [FEAT-001]` | Feature-done QA: full gate (`ci.sh full`) + review (self, or `reviewer`/`consult` for critical) + blackbox manual smoke (`smoke-tester`, new features). Smoke bugs become automated tests |
| `/commit` | Gated conventional commit: runs the canonical `ci.sh fast` via `runner`, generates a `type(scope): description` message, appends `[skip ci]` per `ci-on-claude` |
| `/release patch\|minor\|major` | Bump version + changelog (main session), then `runner` runs `scripts/release.sh` locally (gate → build → publish → deploy). CI release only as fallback |
| `/ship [IDs] \| "topic" [patch\|minor\|major]` | The orchestrator: from a spec list **or** a topic/direction → plan (batch questions) → implement → verify → **local merge** → release → report. Out-of-scope deferrals surfaced in the report |
| `/pr [base]` | **Optional** — open a PR for external review or a repo that requires it. The default flow merges locally with plain git (no PR) |
| `/resume` | Continue interrupted work by reconstructing state from the repo (branch + in-progress spec's unchecked boxes + git log) — works the same in every environment |
| `/consult "question"` | Delegate hard thinking to the `advisor` agent (best/high) — a decision, a design/architecture or debugging idea, or when unsure. You stay on your model (no switch, no cache churn); you brief the advisor with a focused question + curated context. Records the decision in `.claude/memory/decisions.md` when one is made |
| `/unsupervised on [90]\|off` | Toggle autonomous mode (no questions + proactive 90% pause) — see [Unsupervised mode](#unsupervised-mode--resume-logic) |
| `/auto-resume on\|off` | Toggle auto-recovery after a session/rate-limit reset — **independent** of unsupervised; works in supervised too |
| `/workflow-decisions [setting]` | View or change a workflow setting (testing scope, branching, deploy target, ci-on-claude, release-runner, …); edits the live value **and** `docs/workflow/decisions.md` in sync |

## Agents

Seven isolated subagents — each runs in its own context window so heavy reading and noisy output never pollute the main conversation. Three are Haiku (mechanical, high-IO), two are Sonnet/low (`code-explorer`, `smoke-tester`), two are best/high and read-only (`reviewer`, `advisor`). Claude delegates to them automatically based on their descriptions.

| Agent | Role | Used by |
|-------|------|---------|
| `code-explorer` (sonnet/low) | Code-comprehension scout: orients via the project's own docs, then searches with intent (indexes/interfaces/call sites) and explains how the code works in a condensed, sourced briefing (`file:line`). Cites everything, invents nothing | `/plan`, `/project-onboard`, ad-hoc |
| `text-scout` (haiku) | Generic "intelligent grep": reads/searches/filters/summarizes any text — code, logs, docs, transcripts, big command output — into a sourced digest. More than a match, less than code comprehension; never invents | ad-hoc, large-corpus fan-out |
| `runner` (haiku) | Executes a predefined entrypoint (`ci.sh fast/full`, `release.sh`, a named command), digests output → pass/fail + key lines. Never fixes/judges | `/commit`, `/implement`, `/verify`, `/release` |
| `smoke-tester` (sonnet/low) | Drives a running app from explicit prose steps (blackbox — no spec/code), reports failing steps only. Doubles as a novice-usability check. Used proactively wherever a manual check is warranted | `/verify`, `/pr`, ad-hoc |
| `reviewer` (best/high) | Fresh-eyes read-only review of a critical diff — correctness, security, quality, architecture in one pass | `/verify`/`/pr`, critical diffs only |
| `advisor` (best/high) | Top-tier reasoning on a briefed question — a decision, a design/architecture or debugging idea, unsure of the approach. Read-only; advises, never implements | `/consult` |
| `project-scaffolder` (haiku) | Mechanical file creation after design decisions: directories, configs, canonical scripts, CI, docs, initial commit | `/project-init` |

**Why agents and not main-thread work?** Subagents pay a startup overhead but keep the main context clean — the rule of thumb (matching [official guidance](https://code.claude.com/docs/en/best-practices)): anything that reads more than 3-4 files or produces large output goes to a subagent; anything interactive, stateful, or small stays in the main thread. That's why **release/deploy is a skill, not an agent** (sequential, needs user confirmations and main-context state), while planning and implementation judgment stay in the main session.

### Models

**The session runs on whatever model you picked — the workflow never switches it.** No per-ticket tiers, no route skills, no mid-flow model changes (which would invalidate the prompt cache). A few fixed-tier subagents only:

- **Haiku subagents** do the mechanical, high-IO work — `text-scout` (reads/filters/summarizes any text → sourced digest), `runner` (executes the canonical `ci.sh`/`release.sh` → pass/fail + key lines), `project-scaffolder` (init file creation). They keep bulk output off your session model; judgment stays in the main session.
- **`code-explorer` and `smoke-tester` (Sonnet, low effort)** are a notch up: `code-explorer` *understands* how code works (not just locates it) and returns a sourced briefing; `smoke-tester` drives the running app and judges each step against its expected result. Both need a little more reasoning than pure mechanical IO. Used proactively — for most exploration, one `code-explorer` or one `text-scout` call answers it; parallel fan-out is reserved for genuinely large corpora and driven from the main session (subagents can't spawn subagents).
- **`/consult` delegates to the `advisor` agent (best model, high effort)** for hard thinking — stuck twice, an architecture/design idea, a debugging angle, a security call, genuinely unsure. Crucially it does **not** switch your session model (which would invalidate the prompt cache twice, up and back): you stay cached, gather cheaply with the scouts, brief the advisor with a focused question + curated context (whose citations it can follow to read more itself), and it reasons on the top model. The `reviewer` agent (best/high, read-only, fresh eyes) is the review counterpart, used sparingly for genuinely critical diffs.

`best` resolves to Fable when available, else the latest Opus.

**Why a project-aware `code-explorer` over the built-in Explore agent**: a small upgrade for the same job. It runs on Sonnet/low (a bit of code-comprehension reasoning, still cheap) and orients itself first via the project's own guide files (`CLAUDE.md`, `docs/dev/architecture.md`, `docs/workflow/`, `README`, indexes) before targeting a search — so its briefings land on the right code, explain how it works, and cite the project's conventions. It reports facts, sourced; judgment stays with the caller. (For pure text extraction with no code understanding needed, `text-scout` on Haiku is the cheaper primitive.)

Override the agents' model with `CLAUDE_CODE_SUBAGENT_MODEL`, or by editing the `model:` line in `.claude/agents/{name}.md`.

## Key Design Principles

- **Token-efficient**: Only load what's needed. Directory-scoped CLAUDE.md files, Haiku agents for bulk/mechanical work, one model per session (no cache-invalidating switches).
- **Self-contained after init**: Projects get copies of all workflow files. No permanent `--plugin-dir` needed.
- **Local-first, evidence over ceremony**: the canonical `scripts/ci.sh` is the gate (Claude runs the *same* checks CI would); `/verify` proves a change by *running* it. GitHub Actions runs only on human commits + releases — Claude's commits carry `[skip ci]`.
- **Repo is the checkpoint**: state = branch + spec checkboxes + git log, so `/resume` reconstructs identically in every environment — no separate checkpoint file to maintain.
- **Tests that matter**: automated unit/integration/e2e scoped to the ticket, quality over coverage; every bug found by the manual smoke test becomes an automated test.

## Parallel Sessions

You can run multiple Claude Code sessions on the same repository simultaneously — with one constraint: **each session must be on a different git branch**. State lives in the repo (branch + spec checkboxes + git log), so sessions on different branches never collide.

**Safe — recommended pattern:**

| Session | Branch | Task |
|---------|--------|------|
| A | `feature/feat-001-login` | `/implement FEAT-001` |
| B | `develop` | `/plan FEAT-002` |
| C | `feature/feat-003-api` | `/verify` + local merge |

Session A codes, Session B plans a different spec, Session C verifies and merges — all simultaneously, no conflicts.

**Not safe:** two sessions on the **same branch** — they would race on the same files. Don't do it.

**Rule of thumb:** one session per branch. Keep each implementation session on its own feature branch; use a dedicated session on `develop` (or `main`) for planning/drafting.

## Branching Models

`/project-init` asks which model the project uses; all skills adapt automatically:

- **main-only** (default): feature branches merge into `main`; `/release` tags on `main`.
- **git flow**: feature branches merge into `develop`. `master` contains *only released states*: `/release` runs the full gate on `develop`, then merges `develop` → `master` (`--no-ff`), tags the merge commit, and syncs master back into develop. The tip of `master` always equals the latest release.

Both models: **push your feature branch freely** (backups). The gate is the local `/verify` before the **merge**, which is plain local git by default (`/pr` only when you want external review).

## Unsupervised Mode & Resume Logic

Two toggles govern autonomous work — independent, **except that unsupervised implies auto-resume**:

- **`/unsupervised on`** controls *how* Claude works: never asks questions, applies autonomous defaults, keeps working until done or genuinely blocked, and pauses proactively at the usage threshold (default 90%) where usage is readable. Supervised (the default) keeps asking questions and runs to the hard limit with no proactive pause. Turning it on **also turns on `/auto-resume`** if it isn't already — an autonomous run must be able to recover from a limit kill; turning it off leaves auto-resume on.
- **`/auto-resume on`** controls *whether* an interrupted run wakes itself once the limit resets — in **either** mode, toggleable entirely on its own. Its job is to **wake** a stalled cloud session (a limit reset doesn't restart it by itself), not to preserve state: the heartbeat resumes the *same* session, so the chat history and repo are still there. Turn it on when you're around too: the session runs to the limit, then recovers and continues. In supervised mode a recovered run does the mechanical work and records `## Blocked` with a question when a real decision is needed, so you see it on return.

**State is the repo — there is no checkpoint file to maintain.** The branch names the ticket, the in-progress spec's unchecked subtask boxes name the remaining work, and `git log` is the record of what landed. `/resume` reconstructs from these (git wins on disagreement), so it behaves identically in local, cloud, docker, and VS Code sessions. The only branch-memory notes are `## Blocked` (human needed) and `## Ship` (orchestration state).

Because the heartbeat only needs to **wake** the session (not preserve state — the chat history carries that), there's no scratch-note machinery. Arming is handled **script-side** for any work, including free chat: the `auto-resume-guard.sh` `UserPromptSubmit` hook checks, on each prompt, whether `auto_resume` is on and no heartbeat is armed yet — and only then nudges the agent to arm it (one idempotent `create_trigger`; a hook can't call MCP itself). Once armed it's silent for the rest of the session, so there's no per-prompt cost. When the heartbeat later fires and the context shows the work is already finished, the agent deletes it (so you aren't woken needlessly); if work remains it continues and the heartbeat stays armed.

The moving parts:

| Piece | Role |
|-------|------|
| `session-start.sh` (SessionStart hook) | Detects an in-progress spec / `## Ship`; in unsupervised mode emits an AUTO-RESUME directive, else suggests `/resume` |
| `auto-resume-guard.sh` (UserPromptSubmit hook) | While `auto_resume` is on in a cloud session and no heartbeat is armed, nudges the agent to arm it (once); silent once armed |
| `completeness-check.sh` (Stop hook) | In unsupervised mode, blocks stopping while the in-progress spec has unchecked boxes (loop-guarded via `stop_hook_active`) |
| `usage-guard.sh` (PostToolUse hook) | In unsupervised mode only, where usage is readable, pauses at the threshold (default 90%) so you keep headroom. Supervised runs to the hard limit |
| `statusline.sh` (status line) | Shows usage and caches the official `rate_limits` data for the guard |
| recovery heartbeat (cloud) | One recurring Routine armed whenever work is underway (via the hook, or `/implement`/`/ship`/`/resume`/`/unsupervised on`) — wakes a limit-stalled session after reset, self-deletes the first time it fires with nothing left to do; the setting persists |
| `scripts/claude-loop.sh` | **Optional** headless auto-resume for terminal-only/overnight runs (local counterpart of the heartbeat) |

**Pausing at the usage threshold** (unsupervised mode, local terminal / VS Code, where usage is readable via the statusline `rate_limits` field or the OAuth endpoint): at 90% Claude finishes the current atomic step, commits, and ends the turn; it resumes when usage recovers (automatically if `/auto-resume` is on). **In cloud/docker, usage cannot be read** (no credentials file, no headless statusline), and supervised mode has no pre-emptive pause anywhere — the session runs into the limit; if `/auto-resume` is on, the **recovery heartbeat** resumes it after reset. Because the repo is the checkpoint, a kill costs at most the current subtask.

**If the session dies** (crash, hard rate limit, closed laptop) and `/auto-resume` is on: in cloud the heartbeat resumes from the repo automatically; locally, reopening the session triggers the SessionStart hook, or `./scripts/claude-loop.sh` restarts headless sessions that resume from the repo and exit on `## Blocked` or completion. The loop uses `--dangerously-skip-permissions` by default (`CLAUDE_LOOP_PERMISSIONS` to override) — trusted repos only, ideally containerized. A fully-killed local process with no loop running still needs you to reopen it — that's the one environment the heartbeat can't cover.

## Languages Supported

| Language | Formatter | Linter | Tests | Config |
|----------|-----------|--------|-------|--------|
| TypeScript (preferred) | Prettier | ESLint strict | Vitest/Jest | tsconfig.strict.json |
| JavaScript | Prettier | ESLint | Vitest/Jest | → migrate to TS |
| Python | Ruff | Ruff + mypy | pytest | pyproject.toml |
| Rust | rustfmt | clippy | cargo test | Cargo.toml |
| C++ | clang-format | clang-tidy | ctest | CMakeLists.txt |
| Shell | shfmt | shellcheck | bats | — |

New languages: configs are added to `.claude/memory/decisions.md` when first encountered.

## Updating the Plugin

Inside a project that uses this workflow:
```
/workflow-update
```

## Repository Structure

```
.claude-plugin/plugin.json    ← plugin manifest (metadata only; components are auto-discovered)
skills/                       ← one directory per skill ({name}/SKILL.md)
agents/                       ← subagent definitions
templates/
├── CLAUDE.md.template, README.md.template, CONTRIBUTING.md.template
├── CHANGELOG.md.template, spec.md.template, vision.md.template
├── src-claude.md.template, tests-claude.md.template
├── workflow/                 ← workflow doc templates
├── dev/                      ← developer doc templates (setup, style guide, ADR, …)
├── configs/                  ← tsconfig, eslint, pyproject, CMakeLists, etc.
├── github/                   ← CI/release/dependabot workflow templates
├── gitignore/                ← per-language .gitignore templates
├── hooks/                    ← hooks.json (→ project .claude/settings.json) + hook scripts
├── memory/                   ← .gitignore for runtime memory files
└── scripts/                  ← claude-loop.sh (local auto-resume supervisor)
```

## Requirements

- [Claude Code](https://claude.ai/code) with the claude-workflow plugin
- `git`
- `gh` (GitHub CLI) — for GitHub integration
- Language-specific tools (npm, python, cargo, etc.) installed per project needs

## License

MIT
