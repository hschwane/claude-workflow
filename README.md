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
| `/unsupervised on\|off` | Toggle autonomous mode — see [Unsupervised mode](#unsupervised-mode--resume-logic) |

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

Unsupervised mode lets a long task (or a queue of tasks) run without a human, surviving rate limits and session ends. The moving parts:

| Piece | Role |
|-------|------|
| `.claude/memory/settings.md` | `unsupervised: true` — the mode flag, set by `/unsupervised on` |
| `.claude/memory/context.md` | The checkpoint: `## In Progress` with task, branch, last completed step, next step |
| `session-start.sh` (SessionStart hook) | Injects the checkpoint + "AUTO-RESUME REQUIRED" directive into every new session |
| `completeness-check.sh` (Stop hook) | In unsupervised mode, blocks Claude from stopping while `## In Progress` exists (with a loop guard via `stop_hook_active`) |
| `scripts/claude-loop.sh` | Outer supervisor: restarts headless sessions until done or blocked |

The flow:

```
/unsupervised on                      → settings.md flag set
/implement FEAT-001                   → checkpoint written, work starts
        │
        ├─ Claude tries to stop early → Stop hook blocks: "continue from next_step"
        ├─ session dies (rate limit)  → loop waits, starts a FRESH headless session
        │                               (claude -p; checkpoint re-injected by SessionStart hook,
        │                                /resume reads spec + git state and continues)
        ├─ genuine blocker            → Claude writes "## Blocked" → loop exits (code 2)
        └─ all work done              → "## In Progress" cleared  → loop exits (code 0)
```

Run it:
```bash
/unsupervised on          # in Claude Code
/implement FEAT-001       # start the task
./scripts/claude-loop.sh  # in a terminal; then walk away
tail -f .claude/memory/unsupervised.log
```

Design notes:
- Each loop session starts **fresh** instead of `--continue`: all state lives in the checkpoint, fresh sessions are cheaper right after a rate limit, and the first loop run works without a prior conversation.
- The loop runs `claude -p` with `--dangerously-skip-permissions` by default (override via `CLAUDE_LOOP_PERMISSIONS`) — only use it in a trusted repository, ideally in a container/VM.
- Every subtask commit updates the checkpoint, so a resume loses at most one subtask of work.

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
