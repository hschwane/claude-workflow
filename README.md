# wf — a slim workflow for Claude Code

A small plugin that adds the few things current models do not do on their own, and stays out of
the way otherwise. By default Claude works however it judges best; the workflow is opt-in.

```
/plugin install wf --marketplace hschwane/claude-workflow
```

## What it adds

| | |
|---|---|
| `/wf:setup` | New project: interview, decide tests / CI / git / release only where they fit, scaffold a minimal project with a real gate, verify it |
| `/wf:onboard` | Existing project: fit the gate to its own commands, record the decisions |
| `/wf:convert` | A project carrying an older version of this plugin (v1–v3): remove the old copies, keep the decisions, prove the gate still passes |
| `/wf:spec` | Turns a sentence, an idea or a prepared document into specs `/wf:deliver` can build — trivial changes get a one-line spec, bigger ones are cut into small steps |
| `/wf:deliver` | Build one or more specs; a fresh-context `critic` judges each against the spec **and the original bar**; at most 4 fix rounds, then the open findings come back to you |
| `/wf:gauntlet` | A whole goal from whatever you give it: it talks with you until the goal and the bar are clear, then writes specs, delivers them (and releases, if you want) over and over — every builder and critic holds the goal — until it is met or the budget (a share of the weekly allowance, a concurrency limit) is spent. You never write specs |
| `/wf:release` | Version and changelog before the trunk, release script, tag, confirm the live version |
| `guidelines` skill | The maintainer's standing recommendations (UI/UX and style guides, logging, background jobs, Railway, PWA, AI features, bots, maps, charts, changelog). Loaded automatically when a feature is designed |
| `/board` | A spec board pane: specs by status, select several, deliver them. Where no surface draws panes (a cloud session followed in the app), `/board` answers with the board as text |

## What it deliberately does not do
Anything Claude Code already ships: planning (`plan mode`, or just ask), app verification (`/run`,
`/verify`, `/run-skill-generator`), code review (`/code-review`), long-running goals (`/goal`),
memory (auto memory, Projects memory), parallel work (`/batch`, Projects), updates (`/plugin`).

## Per project
`/wf:setup` or `/wf:onboard` leave behind: `scripts/ci.sh` (the gate — the same script CI runs),
optionally `release.sh` / `healthcheck.sh` and a CI workflow, and a short `CLAUDE.md` with a
settings block:

```
<!-- wf:settings -->
- spec-mode: none        # none | files | issues
- branching: main-only   # main-only | git-flow
- trunk: main
- release: none          # none | github | npm | pypi | crates | docker | internal
- deploy: none
- ui: none               # none | test-ui | style-guide
<!-- /wf:settings -->
```

## Developing the plugin
See `CLAUDE.md`. `./scripts/check.sh` before every commit; `./scripts/check.sh --languages`
whenever a stage command, `ci.sh` or anything in `languages/` changes.
