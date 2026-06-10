# claude-workflow

A professional, reusable AI-assisted software development workflow for Claude Code. Covers the full lifecycle from idea to release.

## What It Does

```
/draft → /refine → /implement → /pr → /release
```

An idea enters the backlog as a one-liner, gets refined into a testable spec, is implemented test-first, passes CI and AI reviews in a PR, and ships with a semver release — each step is one command.

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
| `/brainstorm` | The `product-owner` agent analyzes project state vs. vision and proposes ideas; you accept/modify/skip interactively, accepted ideas become drafts |
| `/prioritize` | The `product-owner` agent ranks the backlog against the vision and recommends the slate for the next version |
| `/refine FEAT-001` | `requirements-engineer` and `tech-planner` agents iterate (max 3 rounds) until the spec meets the Definition of Ready: testable acceptance criteria, complete interface definitions, ordered subtasks |
| `/implement FEAT-001` | Phase 1: `test-writer` writes failing tests from the spec alone (never sees implementation code). Phase 2: implement subtask by subtask, one commit + push each. Then full verification via `test-runner` and docs via `documentation-writer` |
| `/commit` | Quality-gated conventional commit: format + lint + type-check first, then a generated `type(scope): description` message |
| `/pr` | Create draft PR → wait for CI → `code-reviewer`, `security-reviewer`, conditionally `architect-reviewer` → fix all findings → squash-merge → move spec to `completed/` |
| `/release patch\|minor\|major` | Test, bump version, update changelog, tag, push; in git flow: merge `develop` → `master` so master's tip equals the release |
| `/resume` | Continue interrupted work from the checkpoint in `.claude/memory/context.md` |
| `/unsupervised on [80]\|off` | Toggle autonomous mode, optionally with a token-budget cap — see [Unsupervised mode](#unsupervised-mode--resume-logic) |

## Agents

Agents are isolated subagents: each runs in its own context window, so heavy file reading and noisy output never pollute the main conversation. Reviewers and analysts are read-only (`disallowedTools: Write, Edit`). Claude delegates to them automatically based on their descriptions.

| Agent | Role | Used by |
|-------|------|---------|
| `code-explorer` | Reads many files, returns a condensed briefing (relevant files, interfaces, patterns, pitfalls) with `file:line` refs | `/refine`, `/project-onboard`, ad-hoc codebase questions |
| `requirements-engineer` | Turns a draft into user story, testable acceptance criteria, out-of-scope list, open questions | `/refine` |
| `tech-planner` | Turns requirements into interface definitions (the test-writer's contract), technical approach, ordered subtasks | `/refine` |
| `product-owner` | Judges ideas/backlog against `docs/VISION.md`, scores relevance, recommends next-version slate | `/brainstorm`, `/prioritize` |
| `test-writer` | Writes the failing test suite from acceptance criteria + interfaces only — by design it cannot see implementation code | `/implement` Phase 1 |
| `test-runner` | Executes test/lint runs and digests the output into a short failure report | `/implement`, `/release` |
| `code-reviewer` | Quality review of the diff: correctness, conventions, tests, complexity | `/pr` |
| `security-reviewer` | OWASP-oriented review: injection, auth, secrets, data exposure | `/pr` |
| `architect-reviewer` | Structural review: module boundaries, dependency direction, AI-friendliness, ADR alignment | `/pr` (only for structural changes) |
| `documentation-writer` | Updates dev/user/API docs from spec + implemented interfaces | `/implement` |
| `workflow-coach` | Answers "how does the workflow work?" questions from `docs/workflow/` so those docs never load into the main context | ad-hoc questions |

**Why agents and not main-thread work?** Subagents pay a startup overhead but keep the main context clean — the rule of thumb (matching [official guidance](https://code.claude.com/docs/en/best-practices)): anything that reads more than 3-4 files or produces large output goes to a subagent; anything interactive, stateful, or small stays in the main thread. That's why **release/deploy is a skill, not an agent** (sequential, needs user confirmations and main-context state), while exploration, test-output digestion, and reviews are agents.

## Key Design Principles

- **Token-efficient**: Only load what's needed. Subdirectory CLAUDE.md files, on-demand agents, CI does the mechanical work.
- **Self-contained after init**: Projects get copies of all workflow files. No permanent `--plugin-dir` needed.
- **CI before AI**: GitHub Actions handles lint/typecheck/test/security. Claude only reviews after CI passes.
- **Isolated subagents**: Code review, security review, test writing — each runs in its own isolated context for unbiased results; reviewers are read-only (`disallowedTools: Write, Edit`).
- **Checkpoint-based resumability**: Every long-running skill saves progress so `/resume` can recover from token limits.
- **Sequential TDD**: Test-writer sees only the spec (not the implementation code). Tests are committed before implementation begins.

## Quick Start

### New Project
```bash
cd ~/my-projects
claude --plugin-dir /path/to/claude-workflow
```
Then in Claude Code:
```
/project-init
```

### Existing Project
```bash
cd my-existing-project
claude --plugin-dir /path/to/claude-workflow
```
Then:
```
/project-onboard
```

After onboarding, the plugin is embedded in `.claude/` — just run `claude` normally.

## Branching Models

`/project-init` asks which model the project uses; all skills adapt automatically:

- **main-only** (default): feature branches merge into `main` via `/pr`; `/release` tags on `main`.
- **git flow**: feature branches merge into `develop` via `/pr`. `master` contains *only released states*: `/release` tests `develop`, then merges `develop` → `master` (`--no-ff`), tags the merge commit, and syncs master back into develop. The tip of `master` always equals the latest release.

Pushing rules in both models: **push your feature branch freely after every commit** — pushes are backups. The quality gate (CI green + AI reviews) applies at the **merge** into the integration branch, which only happens via `/pr`.

## Unsupervised Mode & Resume Logic

Unsupervised mode lets a long task (or a queue of tasks) run without a human. The primary design is **in-session**: you start a task, leave the session open (terminal or VS Code extension — same console, context preserved), and the hooks keep Claude working, pause it when your token budget runs low, and resume it automatically.

```
/unsupervised on 80       # enable; pause at 80% of the 5h or weekly limit
/implement FEAT-001       # start the task, leave the session open
```

The moving parts:

| Piece | Role |
|-------|------|
| `.claude/memory/settings.md` | `unsupervised: true` + optional `usage_threshold: 80` — set by `/unsupervised on [80]` |
| `.claude/memory/context.md` | The checkpoint: task, branch, spec pointer, last/next step (subtask progress lives in the spec's checkboxes) |
| `completeness-check.sh` (Stop hook) | Blocks Claude from stopping while `## In Progress` exists (loop guard via `stop_hook_active`) |
| `usage-guard.sh` (PostToolUse hook) | Watches session (5h) and weekly (7d) usage; trips at the threshold |
| `statusline.sh` (status line) | Shows `ctx \| 5h \| 7d` usage and caches the official `rate_limits` data for the guard |
| `session-start.sh` (SessionStart hook) | Injects the checkpoint + auto-resume directive when a NEW session starts |
| `scripts/claude-loop.sh` | **Optional** headless fallback for terminal-only/overnight scenarios |

The in-session flow:

```
work ──► usage-guard trips at threshold (e.g. 80%)
              │  "pause: commit current step, update checkpoint"
              ▼
         wait loop: bash usage-guard.sh --wait   (repeats, ~90s sleep per call,
              │      same session, same console)  cache-friendly < 5min apart)
              ▼  prints RESUME_OK once usage ≤ threshold−10  (5h window slides)
         continue working ──► … ──► done: "## In Progress" cleared, Stop allowed
```

**Token-budget guard (`usage_threshold`)**: pausing at e.g. 80% keeps 20% headroom for your own interactive use and avoids ever hitting the hard limit mid-task. Usage data comes from the official statusline `rate_limits` field (cached locally) with the community-established OAuth usage endpoint as fallback; if neither is available the guard fails open. Hysteresis (resume at threshold−10) prevents flapping.

**Why in-session?** No context loss, no new consoles, works identically in the CLI and the VS Code extension (hooks and the status line run in both). The wait loop is just repeated short Bash calls ~90s apart, so the prompt cache stays warm — waiting costs almost nothing.

**Checkpoint cost**: a checkpoint update is 1-2 small file edits (~50-100 tokens) per subtask — noise compared to the thousands of tokens a subtask implementation uses. Checkpoints are deliberately minimal (no duplicated subtask lists; the spec's checkboxes are the source of truth) and are pure crash insurance in the in-session design: the running conversation already has the context.

**If the session dies anyway** (crash, hard rate limit, closed laptop): reopen it — the SessionStart hook injects the checkpoint with an AUTO-RESUME directive and Claude continues, in the CLI and in VS Code alike. For fully unattended recovery in a terminal (e.g. overnight on a server) there is `./scripts/claude-loop.sh`, which waits for the usage threshold, starts fresh headless sessions from the checkpoint, and exits on `## Blocked` (code 2) or completion (code 0). It uses `--dangerously-skip-permissions` by default (`CLAUDE_LOOP_PERMISSIONS` to override) — only in trusted repos, ideally containerized.

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
skills/                       ← 13 skills ({name}/SKILL.md per skill)
agents/                       ← 11 agent definitions
templates/
├── CLAUDE.md.template
├── CONTRIBUTING.md.template
├── spec.md.template
├── vision.md.template
├── workflow/                 ← workflow doc templates
├── configs/                  ← tsconfig.strict, eslint, pyproject, CMakeLists, etc.
├── github/                   ← CI/release/dependabot workflow templates
├── hooks/                    ← hooks.json (→ project .claude/settings.json) + hook scripts
└── scripts/                  ← claude-loop.sh (unsupervised mode supervisor)
```

## Requirements

- [Claude Code](https://claude.ai/code) with the claude-workflow plugin
- `git`
- `gh` (GitHub CLI) — for GitHub integration
- Language-specific tools (npm, python, cargo, etc.) installed per project needs

## License

MIT
