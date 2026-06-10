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
  CLAUDE.md.template
  README.md.template
  CONTRIBUTING.md.template
  spec.md.template
  vision.md.template
  workflow/                  ← workflow doc templates
  configs/                   ← standard language configs (tsconfig, eslint, etc.)
  github/                    ← GitHub Actions CI/release templates
  hooks/                     ← hooks.json (becomes project .claude/settings.json) + hook scripts
  scripts/                   ← claude-loop.sh (unsupervised mode supervisor)
```

Note: `templates/hooks/hooks.json` deliberately lives under `templates/` (not `hooks/hooks.json`) so the plugin itself does not activate hooks whose scripts only exist after project-init/onboard copies them into a project's `.claude/hooks/`.

## Skills

| Skill | Description |
|-------|-------------|
| `/project-init` | Create a new project with full infrastructure |
| `/project-onboard` | Add workflow infrastructure to an existing project |
| `/draft` | Add a raw feature/bug to the backlog |
| `/brainstorm` | Analyze project + generate backlog ideas interactively |
| `/prioritize` | Rank backlog against vision, select next-version items |
| `/refine` | RE + Tech Planner iterate until spec is ready |
| `/implement` | Tests-first implementation, per-subtask commits |
| `/commit` | Quality-gated conventional commit |
| `/pr` | CI-first PR with AI review + auto-merge |
| `/release` | Semver bump + changelog + tag + CI publish |
| `/resume` | Resume interrupted work from checkpoint |
| `/unsupervised` | Toggle unsupervised mode (no questions, loop-safe) |
| `/workflow-update` | Update plugin files to a newer version |

## Agents

All agents are subagents — each runs in its own isolated context (unbiased, fresh eyes). Reviewers are read-only via `disallowedTools`.

| Agent | When used |
|-------|-----------|
| `code-explorer` | During `/refine`, `/project-onboard`, ad-hoc — condensed codebase briefings |
| `requirements-engineer` | During `/refine` — structures requirements |
| `tech-planner` | During `/refine` — plans interfaces + subtasks |
| `product-owner` | During `/brainstorm`, `/prioritize` — vision fit + priorities |
| `test-writer` | During `/implement` — writes tests before impl |
| `test-runner` | During `/implement`, `/release` — runs tests, digests output |
| `code-reviewer` | During `/pr` — reviews code quality |
| `security-reviewer` | During `/pr` — reviews for security issues |
| `architect-reviewer` | During `/pr` — reviews structural changes |
| `documentation-writer` | During `/implement` — updates docs after impl |
| `workflow-coach` | Ad-hoc — answers workflow questions from docs/workflow/ |

## Contributing to claude-workflow

To improve the workflow itself:
1. Create a branch: `git checkout -b feature/improve-X`
2. Edit the relevant SKILL.md or agent .md files
3. Test by using the skill in a test project with `--plugin-dir`
4. Commit with conventional commits — **pushing the feature branch after every commit is fine** (pushes are backups; the quality gate is the review at merge time)
5. Merge to `master` only after review (PR or explicit approval) — `master` is what users install from
6. Tag a new version: `git tag v1.x.0`
7. Push: `git push && git push --tags`
