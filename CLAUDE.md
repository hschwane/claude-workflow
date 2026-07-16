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
| `/brainstorm` | Analyze project + generate backlog ideas interactively |
| `/prioritize` | Rank backlog against vision, select next-version items |
| `/refine` | RE + Tech Planner iterate until spec is ready |
| `/implement` | Tests-first implementation, per-subtask commits |
| `/commit` | Quality-gated conventional commit |
| `/pr` | CI-first PR with AI review + auto-merge |
| `/release` | Semver bump + changelog + tag + CI publish |
| `/ship` | Full dev cycle: brainstorm → prioritize → refine → implement → PR → release. Pass ticket IDs (`/ship FEAT-001 FEAT-003`) to skip brainstorm+prioritize and ship exactly those |
| `/resume` | Resume interrupted work from checkpoint (re-arms the routing tier) |
| `/consult` | Top-tier advisor: one elevated turn with full context, then step-down |
| `/route-{sonnet\|opus\|best}-{medium\|high}` | Internal: pin model+effort for the rest of the turn (6 skills; used by refine/implement/pr per the spec routing block) |
| `/unsupervised` | Toggle unsupervised mode (no questions, loop-safe) |
| `/workflow-decisions` | View/change a tunable workflow setting; edits the live skill value + syncs `docs/workflow/decisions.md` |
| `/workflow-update` | Update plugin files to a newer version |

## Agents

All agents are subagents — each runs in its own isolated context (unbiased, fresh eyes). Reviewers are read-only via a `tools: Read, Grep, Glob` allowlist.

Model & effort routing: mechanical agents pin haiku/medium (code-explorer, test-runner, workflow-coach, project-scaffolder), writers sonnet/medium (test-writer, documentation-writer), product-owner sonnet/high; RE/tech-planner pin `effort: high` and get their model per ticket from the refinement tier; reviewers get the review tier per invocation from `/pr`. The main session's tier is set turn-scoped by the six `route-*` skills, driven by each spec's `routing:` block (written during `/refine`) and re-armed from the checkpoint's `tier:` line. See README "Model & effort routing".

| Agent | When used |
|-------|-----------|
| `code-explorer` | During `/refine`, `/project-onboard`, ad-hoc — project-aware Haiku scout; condensed codebase briefings |
| `requirements-engineer` | During `/refine` — structures requirements |
| `tech-planner` | During `/refine` — plans interfaces + subtasks |
| `product-owner` | During `/brainstorm`, `/prioritize` — vision fit + priorities |
| `project-scaffolder` | During `/project-init` — mechanical file creation, template copying, initial commit |
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

## Note for Claude sessions: GitHub operations

If a GitHub MCP operation fails or no MCP tool exists for it (e.g. creating a tag ref), try the `gh` CLI before giving up — it may be installed and authenticated even if the session environment claims otherwise. Check with `gh auth status`, then use `gh api` for anything without a dedicated subcommand, e.g.:

```
gh api repos/<owner>/<repo>/git/refs -f ref="refs/tags/vX.Y.Z" -f sha="<commit-sha>"
```

This also works around cloud-session proxies that reject `git push` for tag refs.
