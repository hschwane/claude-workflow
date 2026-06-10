# claude-workflow

A professional, reusable AI-assisted software development workflow for Claude Code. Covers the full lifecycle from idea to release.

## What It Does

```
/draft → /refine → /implement → /pr → /release
```

| Phase | Skill | What happens |
|-------|-------|-------------|
| Draft | `/draft` | Add raw ideas to the backlog — no planning needed |
| Brainstorm | `/brainstorm` | Analyze project state + generate ideas together |
| Refine | `/refine` | Requirements Engineer + Tech Planner iterate until spec is ready |
| Implement | `/implement` | Tests written first (isolated context), then code per subtask |
| PR | `/pr` | CI runs first, then AI reviews, then auto-merge |
| Release | `/release` | Semver bump, changelog, tag, CI publishes |
| Recovery | `/resume` | Continue interrupted work from a saved checkpoint |

## Key Design Principles

- **Token-efficient**: Only load what's needed. Subdirectory CLAUDE.md files, on-demand agents, CI does the mechanical work.
- **Self-contained after init**: Projects get copies of all workflow files. No permanent `--plugin-dir` needed.
- **CI before AI**: GitHub Actions handles lint/typecheck/test/security. Claude only reviews after CI passes.
- **Isolated agents**: Code review, security review, test writing — all run in `context:fork` for unbiased results.
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
.claude-plugin/plugin.json    ← plugin manifest
skills/                       ← 11 skills (SKILL.md per skill)
agents/                       ← 7 agent definitions
hooks/hooks.json              ← hook config template
templates/
├── CLAUDE.md.template
├── CONTRIBUTING.md.template
├── spec.md.template
├── vision.md.template
├── workflow/                 ← workflow doc templates
├── configs/                  ← tsconfig.strict, eslint, pyproject, CMakeLists, etc.
├── github/                   ← CI/release/dependabot workflow templates
└── hooks/                    ← auto-format, protect-files, completeness-check
```

## Requirements

- [Claude Code](https://claude.ai/code) with the claude-workflow plugin
- `git`
- `gh` (GitHub CLI) — for GitHub integration
- Language-specific tools (npm, python, cargo, etc.) installed per project needs

## License

MIT
