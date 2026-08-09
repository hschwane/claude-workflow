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
.claude-plugin/delivery.json ← ownership of every delivered path: project / plugin / mixed. Drives /workflow-update
languages/                   ← per-language stage commands as DATA (stages.json) + a minimal
                                fixture project. The source of truth the scaffolder reads and
                                `check.sh --languages` executes — prose in an agent file that
                                nothing runs is how three broken commands shipped
skills/                      ← one directory per skill, each with SKILL.md
agents/                      ← subagent definitions (each runs in an isolated context)
templates/                   ← files copied into projects by project-init / project-onboard
  CLAUDE.md.template, README.md.template, CONTRIBUTING.md.template
  CHANGELOG.md.template, spec.md.template, vision.md.template
  src-claude.md.template, tests-claude.md.template
  dev/                       ← developer doc templates: README.md (the index skills read), code-style.md (plugin-owned engineering standards + all language rules), setup, deploy, architecture, user-readme
  configs/                   ← standard language configs (tsconfig, eslint, etc.)
  github/                    ← GitHub Actions CI/release templates
  gitignore/                 ← per-language .gitignore templates
  hooks/                     ← hooks.json (becomes project .claude/settings.json) + hook scripts
  memory/                    ← decisions / gotchas / tech-debt templates (topic index in the head) + .gitignore
  guidelines/                ← standing engineering guidelines, **plugin-owned** (replaced on /workflow-update): README, INDEX.md.template (shipped verbatim, one row per guideline), LIBRARY.md (plugin-side catalogue), and the 12 library files. **Every project gets all of them** — relevance is per task, decided by the INDEX triggers, not per project at install time. Recommendations, not rules — /plan adapts or reasoned-rejects, and only /plan, /project-init and /project-onboard read the index
  ui/                        ← reusable UI templates referenced by a guideline (changelog-template.html, self-contained, re-skin via CSS vars)
  scripts/                   ← canonical entrypoints: ci.sh, release.sh, gate-status.sh (the gate-validity rule as one executable), criteria-check.sh, healthcheck.sh, dev.sh, deploy-reference.sh (git-flow + reference env only); plus claude-loop.sh
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
| `/verify` | **The verification skill** — `ticket\|pr\|release`. Gate, review, criteria table, docs, smoke, at whichever depth the caller needs. `/pr` and `/release` delegate to it |
| `/commit` | Gated conventional commit (runs canonical `ci.sh fast`) |
| `/pr` | **The merge skill** — lands a branch on `develop`, as a real PR or a local fast-forward, same gates either way. Under `main-only` it hands to `/release`: landing on the trunk is releasing |
| `/release` | Bump + changelog **before** the trunk merge, land it, tag, deploy, then assert the live version |
| `/ship` | The orchestrator: spec list OR topic → plan → implement → verify → merge → release. Pass ticket IDs (`/ship FEAT-001 FEAT-003`) or a `"topic"` |
| `/resume` | Resume interrupted work by reconstructing state from the branch + spec checkboxes + git log |
| `/consult` | Delegate hard thinking to the top-tier `advisor` agent — a decision, a design/debugging idea, or when unsure. Session stays on its model (no switch); it briefs the advisor and delegates |
| `/unsupervised` | Toggle unsupervised mode (no questions, autonomous defaults, proactive 90% pause) |
| `/auto-resume` | Toggle auto-recovery after a limit reset (independent of unsupervised; cloud heartbeat / local loop) |
| `/workflow-settings` | View/change a workflow setting — edits the `workflow-settings` block in `CLAUDE.md`, the only place the values live |
| `/workflow-update` | Update plugin files to a newer version |

## Agents

All agents are subagents — each runs in its own isolated context. Three are Haiku (mechanical/high-IO: `text-scout`, `runner`, `project-scaffolder`); two are Sonnet/low (`code-explorer`, `smoke-tester`); two are best/high, read-only (`reviewer`, `advisor`).

Models: the session runs on whatever model the user picked — the workflow does not switch it, ever. The Haiku agents do mechanical high-IO work to keep bulk output off the session model — `text-scout` is the generic "intelligent grep" (reads/filters/summarizes any text with sources), `runner` executes the canonical scripts, `project-scaffolder` does init file creation. `code-explorer` and `smoke-tester` run on Sonnet at low effort — a notch up, because understanding how code works (not just locating it) and judging a live app against expected results each need a bit more reasoning than pure mechanical IO. The best model at high effort lives in two read-only agents: `reviewer` (critical-diff review) and `advisor` (the reasoning `/consult` delegates to). `/consult` is the key move here — instead of switching the session to the top model (which invalidates the prompt cache twice, up and back), the session stays put, briefs the `advisor` agent with a focused question + curated context, and delegates just the hard thinking.

Exploration: for most tasks reach for **one** `code-explorer` (understand code) **or** one `text-scout` (extract/summarize text) — a single call answers it. Fanning out several `text-scout`s in parallel, or a multi-stage sweep, is reserved for genuinely large codebases / text corpora in complex apps. Subagents can't spawn subagents, so any fan-out is driven from the main session, not from inside an agent. Both agents cite every claim and never invent — their digests are trusted without re-reading.

| Agent | When used |
|-------|-----------|
| `code-explorer` (sonnet/low) | During `/plan`, `/project-onboard`, ad-hoc — code-comprehension scout; orients via project docs, then targeted search; condensed, sourced briefings |
| `text-scout` (haiku) | Ad-hoc — generic "intelligent grep": reads/searches/filters/summarizes any text (code, logs, docs, output) into a sourced digest |
| `runner` (haiku) | During `/commit`, `/implement`, `/verify`, `/release` — runs a canonical entrypoint (`ci.sh`/`release.sh`), digests output |
| `smoke-tester` (sonnet/low) | During `/verify`, `/pr`, or ad-hoc — drives the app from prose steps (blackbox), reports failing steps; used proactively whenever a manual check is warranted |
| `reviewer` (best/high) | During `/verify`/`/pr` for critical diffs only — fresh-eyes read-only review |
| `advisor` (best/high) | During `/consult` — top-tier reasoning on a briefed question (decision, design/debugging idea, unsure of approach); read-only, advises, never implements |
| `project-scaffolder` (haiku) | During `/project-init` — mechanical file creation, template copying, initial commit |

## Changing the workflow — how, and how it gets tested

This plugin is prose that another model executes. That makes it a peculiar kind of software:
it has no compiler, most of it cannot be unit-tested, and a change that reads perfectly can be
impossible to follow. Four releases of evidence say so — rounds of review found 6, then 12, then
23, then 29 defects, and several in each round were regressions on the previous round's fixes.

So the rule is: **anything that can be executed must be executed, and everything else gets
asserted.** Reading it again is the weakest instrument here, not the strongest.

### The three checks, in order of how much they prove

| | Catches | Cost |
|---|---|---|
| `./scripts/check.sh` | contradictions *between files* — a rule stated twice at two strengths, a token nobody fills, a manifest entry with no owner | seconds |
| `./scripts/check.sh --languages` | commands that **do not work**: wrong flag, wrong syntax, a selection that silently matches nothing | ~4 min, installs toolchains |
| a live agent run (below) | instructions that are ambiguous, contradictory, or impossible for a fresh reader to follow | ~20 min, ~180k tokens |

Run the first on every change. Run the second whenever you touch a stage command, `ci.sh`, or
anything in `languages/`. Run the third before a release, or after restructuring a skill.

### Making a change

1. Branch: `git checkout -b feature/improve-X`.
2. Make the change. **If it is a per-language command, edit `languages/<lang>/stages.json`** —
   not the table in `project-scaffolder.md`, which now summarises that file. Its `notes` field
   says why each command has the shape it does; read them before changing one.
3. **Add an assertion.** Every cross-file claim gets a case in `scripts/_check_consistency.py`;
   every executable claim gets a row in the language matrix. A fix with no assertion is a fix
   that comes back — this has happened enough times to be a rule rather than advice.
4. **Verify the assertion is load-bearing**: break the thing it guards and confirm it fails. An
   assertion that passes on a broken tree is worse than none, because it reads as coverage.
5. `./scripts/check.sh` (and `--languages` if step 2 applies).
6. Conventional commit. Pushing the feature branch after every commit is fine — pushes are
   backups; the gate is the review at merge time.
7. Merge to `master` only after review — `master` is what users install from.
8. `git tag vX.Y.Z && git push && git push --tags`.

### Testing with a live agent run

The only thing that finds "a fresh reader cannot follow this". Give an agent the skill or agent
definition, a decisions block, and a real empty directory — then ask for two things: the work,
**and** a list of every instruction that was ambiguous, contradictory, incomplete or impossible,
quoting it. Tell it explicitly that "no defects found" is a valid answer, or it will invent some.

What makes these runs worth the cost:
- **Vary the shape.** A TypeScript web app and a Python library exercise different halves. Every
  round that changed the shape found defects the previous shape could not reach — a library
  broke `healthcheck.sh`, a `main-only` CLI broke the release path, an existing repo on a branch
  named `trunk` broke assumptions four skills shared.
- **Ask for counts, not exit codes.** "The gate passed" and "the gate passed having run zero
  tests" are the same exit code. The worst defect in this project's history hid in that gap.
- **Run init and onboard in parallel.** They find disjoint sets: init finds instructions that
  produce a broken artifact, onboard finds instructions that collide with a codebase that
  already has opinions.

### Things this project has learned the hard way

- **A guard that cannot be satisfied is a dead end, not a safeguard.** Check every refusal has a
  reachable path out, and that the path is documented where the person hitting it will look.
- **Escape hatches need somewhere to live.** `.claude/gate-overrides.env`, not an environment
  variable in whoever's shell — or local and CI disagree and the parity guarantee is gone.
- **Prose that assumes a deployed web app breaks libraries and CLIs.** Most defects in the last
  two rounds were this, in different disguises.
- **Fixing one defect frequently introduces the next one in the same paragraph.** Re-read the
  whole passage after an edit, not just the sentence you changed, and prefer a `python` patch
  with an exact-match assertion over a loose `sed`: two corruptions in this repo came from a
  replacement matching somewhere it was never meant to.

## Note for Claude sessions: GitHub operations

The `gh` CLI is authenticated and available in **every** session, including cloud/web ones — even when the environment claims otherwise. Whenever plain git or a GitHub MCP operation fails at something GitHub-side (a proxy rejecting `git push` of tags or to a protected branch, a ref git can't create, a missing MCP tool), fall back to `gh` before giving up. Use `gh api` for anything without a dedicated subcommand:

```
gh api repos/<owner>/<repo>/git/refs -f ref="refs/tags/vX.Y.Z" -f sha="<commit-sha>"      # create a tag
gh api -X PATCH repos/<owner>/<repo>/git/refs/heads/master -f sha="<sha>"                  # fast-forward a branch
```

Cloud gotcha: the git remote is often a proxy URL `gh` can't parse, so pass **`-R <owner>/<repo>`** on `gh` subcommands (e.g. `gh release create vX.Y.Z -R owner/repo …`, `gh pr …`). This is how this repo's releases (proxy blocks `git push` of tags/master) are cut.
