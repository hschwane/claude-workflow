# claude-workflow

This repository IS the claude-workflow plugin. It provides a professional AI-assisted software development workflow for use with Claude Code.

## How to Use This in a Project

**New project:**
```
claude --plugin-dir /path/to/claude-workflow
/project-init
```

**Existing project:**
```
claude --plugin-dir /path/to/claude-workflow
/project-onboard
```

After onboarding, the plugin files are copied into the project's `.claude/` directory — the project becomes self-contained and no longer needs `--plugin-dir`.

## Repository Structure

```
.claude-plugin/plugin.json   ← plugin manifest (metadata only; skills/ and agents/ are auto-discovered)
skills/                      ← one directory per skill, each with SKILL.md
agents/                      ← subagent definitions (each runs in an isolated context)
templates/                   ← files copied into projects by project-init / project-onboard
  CLAUDE.md.template, README.md.template, CONTRIBUTING.md.template
  CHANGELOG.md.template, spec.md.template, vision.md.template
  src-claude.md.template, tests-claude.md.template
  workflow/                  ← workflow doc templates
  dev/                       ← developer doc templates (setup, style guide, ADR, …)
  configs/                   ← standard language configs (tsconfig, eslint, etc.)
  github/                    ← GitHub Actions CI/release templates
  gitignore/                 ← per-language .gitignore templates
  hooks/                     ← hooks.json (becomes project .claude/settings.json) + hook scripts
  memory/                    ← .gitignore for runtime memory files
  scripts/                   ← claude-loop.sh (unsupervised mode supervisor)
```

Note: `templates/hooks/hooks.json` deliberately lives under `templates/` (not `hooks/hooks.json`) so the plugin itself does not activate hooks whose scripts only exist after project-init/onboard copies them into a project's `.claude/hooks/`.

## Skills

| Skill | Description |
|-------|-------------|
| `/project-init` | Create a new project with full infrastructure |
| `/project-onboard` | Add workflow infrastructure to an existing project |
| `/draft` | Add a raw feature/bug to the backlog |
| `/plan` | Turn draft(s) into ready spec(s) — one light pass, batches questions |
| `/implement` | Per-subtask code+tests, fast gate each, then `/verify` |
| `/verify` | Feature-done QA: full gate + review + manual smoke |
| `/commit` | Gated conventional commit (runs canonical `ci.sh fast`) |
| `/pr` | Optional — open a PR for external review (default merges locally) |
| `/release` | Semver bump + changelog, then run `release.sh` locally |
| `/ship` | The orchestrator: spec list OR topic → plan → implement → verify → merge → release. Pass ticket IDs (`/ship FEAT-001 FEAT-003`) or a `"topic"` |
| `/resume` | Resume interrupted work by reconstructing state from the branch + spec checkboxes + git log |
| `/consult` | Top-tier advisor: one elevated turn (best/high) with full context, then back to the session model |
| `/unsupervised` | Toggle unsupervised mode (no questions, loop-safe) |
| `/workflow-decisions` | View/change a tunable workflow setting; edits the live skill value + syncs `docs/workflow/decisions.md` |
| `/workflow-update` | Update plugin files to a newer version |

## Agents

All agents are subagents — each runs in its own isolated context. Four of five are Haiku (mechanical, high-IO); the `reviewer` is best/high, read-only.

Models: the session runs on whatever model the user picked — the workflow does not switch it. The Haiku agents (`code-explorer`, `runner`, `smoke-tester`, `project-scaffolder`) do mechanical high-IO work to keep bulk output off the session model; `/consult` and the `reviewer` agent reach for the best model at high effort only when a hard call or a critical review warrants it.

| Agent | When used |
|-------|-----------|
| `code-explorer` (haiku) | During `/plan`, `/project-onboard`, ad-hoc — project-aware scout; condensed codebase briefings |
| `runner` (haiku) | During `/commit`, `/implement`, `/verify`, `/release` — runs a canonical entrypoint (`ci.sh`/`release.sh`), digests output |
| `smoke-tester` (haiku) | During `/verify` — drives the app from prose steps (blackbox), reports failing steps |
| `reviewer` (best/high) | During `/verify`/`/pr` for critical diffs only — fresh-eyes read-only review |
| `project-scaffolder` (haiku) | During `/project-init` — mechanical file creation, template copying, initial commit |

## Contributing to claude-workflow

To improve the workflow itself:
1. Create a branch: `git checkout -b feature/improve-X`
2. Edit the relevant SKILL.md or agent .md files
3. Test by using the skill in a test project with `--plugin-dir`
4. Commit with conventional commits — **pushing the feature branch after every commit is fine** (pushes are backups; the quality gate is the review at merge time)
5. Merge to `master` only after review (PR or explicit approval) — `master` is what users install from
6. Tag a new version: `git tag v1.x.0`
7. Push: `git push && git push --tags`

## Note for Claude sessions: GitHub operations

If a GitHub MCP operation fails or no MCP tool exists for it (e.g. creating a tag ref), try the `gh` CLI before giving up — it may be installed and authenticated even if the session environment claims otherwise. Check with `gh auth status`, then use `gh api` for anything without a dedicated subcommand, e.g.:

```
gh api repos/<owner>/<repo>/git/refs -f ref="refs/tags/vX.Y.Z" -f sha="<commit-sha>"
```

This also works around cloud-session proxies that reject `git push` for tag refs.
