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
| `/refine FEAT-001` | Depth scales with a complexity triage: **trivial** specs get one combined `tech-planner` fast-track pass (escalates itself if it finds hidden complexity); **small/medium/large** run the full `requirements-engineer` + `tech-planner` iteration (max 1 / 1 / 3 rounds) until the spec meets the Definition of Ready — small/medium on opus-high, large on best-high (trivial's fast-track runs sonnet-high). Writes the per-ticket `routing:` block. Bug tickets pull platform logs (e.g. Railway) as evidence first. Pass **multiple IDs** to batch: questions up front, then all tickets complete autonomously |
| `/implement FEAT-001` | Phase 1: `test-writer` writes failing tests from the spec alone (never sees implementation code). Phase 2: implement subtask by subtask, one commit + push each. Then full verification via `test-runner` and docs via `documentation-writer` |
| `/commit` | Quality-gated conventional commit: format + lint + type-check first, then a generated `type(scope): description` message |
| `/pr` | Create draft PR → wait for CI → reviews scaled to the diff: small low-risk diffs get one combined review, anything touching security-sensitive files gets the dedicated `security-reviewer` (plus `code-reviewer`, conditionally `architect-reviewer`) → fix all blocking findings (small diffs: suggestions auto-fixed too; otherwise suggestions are listed in the final report) → squash-merge → move spec to `completed/` |
| `/release patch\|minor\|major` | Test, bump version, update changelog, tag, push; in git flow: merge `develop` → `master` so master's tip equals the release |
| `/ship [focus] [patch\|minor\|major]` | Full dev cycle in one command: brainstorm → prioritize → refine → implement → PR → release |
| `/resume` | Continue interrupted work from the checkpoint in `.claude/memory/context-{branch}.md` (re-arms the ticket's model/effort tier, then recovers any subagents left in flight by the crash) |
| `/consult "question"` | Ask the top-tier advisor: one elevated turn (best/medium) with full session context, records the decision in `.claude/memory/decisions.md`, steps back down |
| `/unsupervised on [80]\|off` | Toggle autonomous mode, optionally with a token-budget cap — see [Unsupervised mode](#unsupervised-mode--resume-logic) |
| `/workflow-decisions [setting]` | View or change a tunable workflow setting (refine sizing, testing scope, review tier, branching, auto-merge, …). Edits the live value in the skill **and** updates `docs/workflow/decisions.md` in sync — that file is the human-readable record of every workflow decision |

## Agents

Agents are isolated subagents: each runs in its own context window, so heavy file reading and noisy output never pollute the main conversation. The three reviewers are hard read-only (`tools: Read, Grep, Glob` — no Bash, no write tools); the other analysts are read-only by instruction plus `disallowedTools: Write, Edit, NotebookEdit`. Claude delegates to them automatically based on their descriptions.

| Agent | Role | Used by |
|-------|------|---------|
| `code-explorer` | Project-aware Haiku scout: orients via the project's own docs, then reads many files and returns a condensed briefing (relevant files, interfaces, patterns, pitfalls) with `file:line` refs | `/refine`, `/project-onboard`, ad-hoc codebase questions |
| `requirements-engineer` | Turns a draft into user story, testable acceptance criteria, out-of-scope list, open questions | `/refine` |
| `tech-planner` | Turns requirements into interface definitions (the test-writer's contract), technical approach, ordered subtasks | `/refine` |
| `product-owner` | Judges ideas/backlog against `docs/VISION.md`, scores relevance, recommends next-version slate | `/brainstorm`, `/prioritize` |
| `project-scaffolder` | Mechanical file creation after design decisions: directories, language configs, CI templates, docs, workflow infrastructure, initial commit — runs on Haiku, it only copies and fills | `/project-init` scaffolding phase |
| `test-writer` | Writes the failing test suite from acceptance criteria + interfaces only — by design it cannot see implementation code | `/implement` Phase 1 |
| `test-runner` | Executes test/lint runs and digests the output into a short failure report | `/implement`, `/release` |
| `code-reviewer` | Quality review of the diff: correctness, conventions, tests, complexity | `/pr` |
| `security-reviewer` | OWASP-oriented review: injection, auth, secrets, data exposure | `/pr` |
| `architect-reviewer` | Structural review: module boundaries, dependency direction, AI-friendliness, ADR alignment | `/pr` (only for structural changes) |
| `documentation-writer` | Updates dev/user/API docs from spec + implemented interfaces | `/implement` |
| `workflow-coach` | Answers "how does the workflow work?" questions from `docs/workflow/` so those docs never load into the main context | ad-hoc questions |

**Why agents and not main-thread work?** Subagents pay a startup overhead but keep the main context clean — the rule of thumb (matching [official guidance](https://code.claude.com/docs/en/best-practices)): anything that reads more than 3-4 files or produces large output goes to a subagent; anything interactive, stateful, or small stays in the main thread. That's why **release/deploy is a skill, not an agent** (sequential, needs user confirmations and main-context state), while exploration, test-output digestion, and reviews are agents.

### Model & effort routing

The workflow routes **model** and **effort** per task so quality lands where it pays (planning, review) and everything else runs cheap. **Recommended session model: Sonnet** — the workflow elevates itself.

**Fixed agent pins** (`model:`/`effort:` frontmatter):

| Tier | Agents | Rationale |
|------|--------|-----------|
| haiku / medium | `code-explorer`, `test-runner`, `workflow-coach`, `project-scaffolder` | Gather, run, condense, copy — no deep reasoning needed; Haiku costs ~⅓ of Sonnet |
| sonnet / medium | `test-writer`, `documentation-writer` (and `/draft`) | Solid writing; the hard thinking happened upstream. The test-writer's *model* still follows the ticket routing |
| sonnet / high | `product-owner` | Vision-fit judgment, bounded depth |
| effort high, model per ticket | `requirements-engineer`, `tech-planner` | Planning is where quality pays — the model comes from the ticket's refinement tier |
| per review tier | `code-reviewer`, `security-reviewer`, `architect-reviewer` | Model passed per invocation from the review-tier rule in `/pr` |

**Per-ticket routing**: `/refine` triages each ticket (trivial → sonnet-high, small/medium → opus-high, large → best-high refinement) and the `tech-planner` writes a `routing:` block into the spec (implementation `sonnet-medium` by default, up to `best-medium` for the hardest tickets; tests on `sonnet`/`opus`). `/implement` and `/pr` apply these via **route skills** (`route-sonnet-medium` … `route-best-high`) — tiny skills whose frontmatter pins model+effort for the rest of the turn, then reverts on the next prompt. The checkpoint's `tier:` line re-arms the tier after every wake (`/resume`). `best` resolves to Fable when available, else the latest Opus; if Fable access ends, switch to the Opus-compensated mapping (opus/high · opus/xhigh) via `/workflow-decisions top-tier`.

**Adaptive routing**: the planned tier is a starting point, not a straitjacket. On clear failure signals (same error twice, plan vs. reality mismatch, unexpected security/architecture scope) Claude first consults the advisor — `/consult` runs one turn on the top tier with full session context, records the decision, steps back down — and only re-routes upward when the remaining execution itself needs it (medium threshold; ceiling best-medium for implementation). De-escalation has a high threshold (subtask boundary, clearly mechanical remainder). Refinement and review gates are never self-adjusted. Toggle via `/workflow-decisions adaptive routing`.

**Why a project-aware `code-explorer` instead of the built-in Explore agent**: Claude Code ships a generic built-in Explore agent (Haiku, read-only), but it knows nothing about how *your* project is laid out — where the docs live, what the conventions are. `code-explorer` runs on the same cheap Haiku tier but orients itself first via the project's own guide files (`CLAUDE.md`, `docs/dev/architecture.md`, `docs/workflow/`, `README`), so its briefings land on the right code faster and cite the project's own conventions. It reports facts (files, interfaces, patterns, call sites); the judgment and planning stay with the caller — the main session or the `tech-planner`, both of which run your session model with full task context. Prefer it over the built-in Explore for any work in this project.

Overrides, from broadest to narrowest:
- `CLAUDE_CODE_SUBAGENT_MODEL` env var forces one model for **all** subagents (beats everything)
- Edit the `model:` line in `.claude/agents/{name}.md` in your project (after init/onboard the files are local)
- Skill frontmatter `model:`/`effort:` is turn-scoped and deliberate: the six `route-*` skills and `/consult` ARE the routing mechanism, and `/draft` pins sonnet/medium for cheap capture. A skill-set tier persists for the rest of the turn — that's why every workflow skill arms its own tier explicitly (and steps down after expensive phases) rather than assuming a clean slate.

## Key Design Principles

- **Token-efficient**: Only load what's needed. Subdirectory CLAUDE.md files, on-demand agents, CI does the mechanical work.
- **Self-contained after init**: Projects get copies of all workflow files. No permanent `--plugin-dir` needed.
- **CI before AI**: GitHub Actions handles lint/typecheck/test/security. Claude only reviews after CI passes.
- **Isolated subagents**: Code review, security review, test writing — each runs in its own isolated context for unbiased results; reviewers are hard read-only (`tools: Read, Grep, Glob`).
- **Checkpoint-based resumability**: Every long-running skill saves progress so `/resume` can recover from token limits. Checkpoints also track in-flight subagents (`subagents:` block), so a session that crashed mid-dispatch re-runs only the subagents whose results were lost — verifying each one's output before deciding continue-vs-restart.
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

**Cloud/remote sessions** (Claude Code on the web, or any managed session without an attached terminal — detectable by the presence of a schedule-a-future-message tool like `send_later` or `ScheduleWakeup`): the `--wait` sleep loop would burn turns and can hit session limits, so Claude instead runs the one-shot `usage-guard.sh --check`, and if usage is still above the resume level, schedules a wakeup 20–30 minutes out and goes idle. Each wakeup re-checks until `RESUME_OK`, then work continues from the checkpoint. The same scheduled-wakeup pattern replaces the CI/merge polling sleeps in `/pr` and `/release`.

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
└── scripts/                  ← claude-loop.sh (unsupervised mode supervisor)
```

## Requirements

- [Claude Code](https://claude.ai/code) with the claude-workflow plugin
- `git`
- `gh` (GitHub CLI) — for GitHub integration
- Language-specific tools (npm, python, cargo, etc.) installed per project needs

## License

MIT
