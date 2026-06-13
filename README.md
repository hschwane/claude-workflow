# claude-workflow

A professional, reusable AI-assisted software development workflow for Claude Code. Covers the full lifecycle from idea to release.

## What It Does

```
/draft → /refine → /implement → /pr → /release
```

An idea enters the backlog as a one-liner, gets refined into a testable spec, is implemented test-first, passes CI and AI reviews in a PR, and ships with a semver release — each step is one command.

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
| `/brainstorm` | The `product-owner` agent analyzes project state vs. vision and proposes ideas; you accept/modify/skip interactively, accepted ideas become drafts |
| `/prioritize` | The `product-owner` agent ranks the backlog against the vision and recommends the slate for the next version |
| `/refine FEAT-001` | Depth scales with a complexity triage: **small** specs get one combined `tech-planner` fast-track pass (escalates itself if it finds hidden complexity); **medium/large** specs run the full `requirements-engineer` + `tech-planner` iteration (max 1 / 3 rounds) until the spec meets the Definition of Ready |
| `/implement FEAT-001` | Phase 1: `test-writer` writes failing tests from the spec alone (never sees implementation code). Phase 2: implement subtask by subtask, one commit + push each. Then full verification via `test-runner` and docs via `documentation-writer` |
| `/commit` | Quality-gated conventional commit: format + lint + type-check first, then a generated `type(scope): description` message |
| `/pr` | Create draft PR → wait for CI → reviews scaled to the diff: small low-risk diffs get one combined review, anything touching security-sensitive files gets the dedicated `security-reviewer` (plus `code-reviewer`, conditionally `architect-reviewer`) → fix all findings → squash-merge → move spec to `completed/` |
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
| `project-scaffolder` | Mechanical file creation after design decisions: directories, language configs, CI templates, docs, workflow infrastructure, initial commit — runs on Sonnet to save tokens during `/project-init` | `/project-init` scaffolding phase |
| `test-writer` | Writes the failing test suite from acceptance criteria + interfaces only — by design it cannot see implementation code | `/implement` Phase 1 |
| `test-runner` | Executes test/lint runs and digests the output into a short failure report | `/implement`, `/release` |
| `code-reviewer` | Quality review of the diff: correctness, conventions, tests, complexity | `/pr` |
| `security-reviewer` | OWASP-oriented review: injection, auth, secrets, data exposure | `/pr` |
| `architect-reviewer` | Structural review: module boundaries, dependency direction, AI-friendliness, ADR alignment | `/pr` (only for structural changes) |
| `documentation-writer` | Updates dev/user/API docs from spec + implemented interfaces | `/implement` |
| `workflow-coach` | Answers "how does the workflow work?" questions from `docs/workflow/` so those docs never load into the main context | ad-hoc questions |

**Why agents and not main-thread work?** Subagents pay a startup overhead but keep the main context clean — the rule of thumb (matching [official guidance](https://code.claude.com/docs/en/best-practices)): anything that reads more than 3-4 files or produces large output goes to a subagent; anything interactive, stateful, or small stays in the main thread. That's why **release/deploy is a skill, not an agent** (sequential, needs user confirmations and main-context state), while exploration, test-output digestion, and reviews are agents.

### Model routing

Each agent pins the cheapest model that reliably does its job (`model` frontmatter); only the judgment-heavy agents follow your session model. This mirrors the established pattern — plan/review with the strongest model, execute with Sonnet, extract/digest with Haiku (the built-in Explore agent runs on Haiku for the same reason):

| Tier | Agents | Rationale |
|------|--------|-----------|
| `haiku` (cheapest, ~⅓ of Sonnet) | `test-runner`, `workflow-coach` | Mechanical: run commands and condense output; answer questions from structured docs. No deep reasoning needed |
| `sonnet` (workhorse) | `code-explorer`, `test-writer`, `documentation-writer`, `product-owner`, `project-scaffolder` | Solid code understanding and writing, but the hard thinking already happened upstream (specs, vision). Pinning saves significantly when your session runs Opus/Fable |
| `inherit` (your session model) | `requirements-engineer`, `tech-planner`, `code-reviewer`, `security-reviewer`, `architect-reviewer` | Planning and reviews are where model quality pays off most. You control the tier with `/model` — run Opus for a tricky refinement, Sonnet for routine work |

**Interactive tier choice**: `/refine` and `/pr` ask once per run (supervised mode only) which tier their `inherit`-agents should use — **session model** (recommended) / **better than Sonnet** (Opus, Fable, … lumped together; passed as `opus`) / **Sonnet** / **Haiku**. The answer is passed as the per-invocation `model` parameter (resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` env var > per-invocation parameter > agent frontmatter > session model), so your session model itself never changes. Pinned agents (haiku/sonnet tiers above) are unaffected. In unsupervised mode the question is skipped and the session model applies.

**Pure discovery vs. understanding**: for "where is X?" questions Claude Code's **built-in Explore agent** (Haiku, read-only) is the right tool — the plugin deliberately ships no duplicate. `code-explorer` (Sonnet) is for briefings that need judgment: patterns, pitfalls, interface summaries.

Overrides, from broadest to narrowest:
- `CLAUDE_CODE_SUBAGENT_MODEL` env var forces one model for **all** subagents (beats everything)
- Edit the `model:` line in `.claude/agents/{name}.md` in your project (after init/onboard the files are local)
- Skills deliberately do **not** set `model:` — a skill's model override would change the main conversation's model for the rest of the turn, which is surprising when skills chain (e.g. `/pr` running `/commit`). The one exception is `/draft` (pinned to `haiku`): its work is purely mechanical (parse input, find the next ID, write a template entry, optional `gh issue create`) and gets fully reworked in `/refine`, so the cheapest model suffices. It's safe because `/draft` is a leaf skill — it never invokes other skills, and the `/brainstorm` path inlines draft's behavior rather than invoking it as a skill, so the model override doesn't leak into a brainstorm turn.

## Key Design Principles

- **Token-efficient**: Only load what's needed. Subdirectory CLAUDE.md files, on-demand agents, CI does the mechanical work.
- **Self-contained after init**: Projects get copies of all workflow files. No permanent `--plugin-dir` needed.
- **CI before AI**: GitHub Actions handles lint/typecheck/test/security. Claude only reviews after CI passes.
- **Isolated subagents**: Code review, security review, test writing — each runs in its own isolated context for unbiased results; reviewers are read-only (`disallowedTools: Write, Edit`).
- **Checkpoint-based resumability**: Every long-running skill saves progress so `/resume` can recover from token limits.
- **Sequential TDD**: Test-writer sees only the spec (not the implementation code). Tests are committed before implementation begins.

## Parallel Sessions

You can run multiple Claude Code sessions on the same repository simultaneously — with one constraint: **each session must be on a different git branch**. Each branch gets its own isolated checkpoint file (`.claude/memory/context-{branch}.md`), so sessions never collide.

**Safe — recommended pattern:**

| Session | Branch | Task |
|---------|--------|------|
| A | `feature/feat-001-login` | `/implement FEAT-001` |
| B | `develop` | `/refine FEAT-002` or `/brainstorm` |
| C | `feature/feat-003-api` | `/pr` waiting for CI |

Session A codes, Session B refines a different spec, Session C handles a PR — all simultaneously, no conflicts.

**Not safe:** two sessions on the **same branch**. They share the same checkpoint file and can conflict on source files. Don't do it.

**Rule of thumb:** one session per branch. Keep each implementation session on its own feature branch. Use a dedicated session on `develop` (or `main`) for planning work (refine, draft, brainstorm) that doesn't touch feature code.

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
├── README.md.template
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
