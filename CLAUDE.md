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
.claude-plugin/plugin.json   ← plugin manifest (skills + agents + hooks)
skills/                      ← one directory per skill, each with SKILL.md
agents/                      ← agent definitions (all run context:fork)
hooks/hooks.json             ← hook configuration template
templates/                   ← files copied into projects by project-init
  CLAUDE.md.template
  CONTRIBUTING.md.template
  spec.md.template
  vision.md.template
  workflow/                  ← workflow doc templates
  configs/                   ← standard language configs (tsconfig, eslint, etc.)
  github/                    ← GitHub Actions CI/release templates
  hooks/                     ← hook shell scripts
```

## Skills

| Skill | Description |
|-------|-------------|
| `/project-init` | Create a new project with full infrastructure |
| `/project-onboard` | Add workflow infrastructure to an existing project |
| `/draft` | Add a raw feature/bug to the backlog |
| `/brainstorm` | Analyze project + generate backlog ideas interactively |
| `/refine` | RE + Tech Planner iterate until spec is ready |
| `/implement` | Tests-first implementation, per-subtask commits |
| `/commit` | Quality-gated conventional commit |
| `/pr` | CI-first PR with AI review + auto-merge |
| `/release` | Semver bump + changelog + tag + CI publish |
| `/resume` | Resume interrupted work from checkpoint |
| `/workflow-update` | Update plugin files to a newer version |

## Agents

All agents run with `context: fork` (isolated, unbiased).

| Agent | When used |
|-------|-----------|
| `requirements-engineer` | During `/refine` — structures requirements |
| `tech-planner` | During `/refine` — plans interfaces + subtasks |
| `test-writer` | During `/implement` — writes tests before impl |
| `code-reviewer` | During `/pr` — reviews code quality |
| `security-reviewer` | During `/pr` — reviews for security issues |
| `architect-reviewer` | During `/pr` — reviews structural changes |
| `documentation-writer` | During `/implement` — updates docs after impl |

## Contributing to claude-workflow

To improve the workflow itself:
1. Create a branch: `git checkout -b feature/improve-X`
2. Edit the relevant SKILL.md or agent .md files
3. Test by using the skill in a test project with `--plugin-dir`
4. Commit with conventional commits
5. Tag a new version: `git tag v1.x.0`
6. Push: `git push && git push --tags`
