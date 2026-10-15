---
name: setup
description: Set up a new project with the wf workflow — interview the user, decide tests, CI, docs, git and release only where they fit the project, scaffold a minimal working project with a real gate, and verify it. Use when the user starts a new project or asks to set one up.
argument-hint: "[project name or idea]"
---

# Setup

A new project, small and working, with the decisions that matter written down once. Plugin files
live at `${CLAUDE_PLUGIN_ROOT}`; nothing from the plugin is copied into the project except what is
named here. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/decisions.md` for the interview and what each
answer produces — `onboard` uses the same file.

**Lead and workers** (`${CLAUDE_PLUGIN_ROOT}/shared/workers.md`): the interview and the yes stay with you; sections 2–3
can go to one worker with the agreed decisions in its brief — in a Project, a thread.

## 1. Interview
Ask in one batch (plain chat, numbered), then follow up only where an answer opens a real question:
- What it is, for whom, and how it will be used (script, library, CLI, web app, service, bot …).
- Language and, if they have a view, framework. Load the `guidelines` skill and read the matching
  guidelines before recommending a stack; recommend one concrete stack, with the reason.
- The decisions in `decisions.md`, **only those that apply** — a script needs no release process,
  a library no deploy, a CLI no UI.
Show the resulting decisions as a short list and get a yes before writing anything.

## 2. Scaffold
In the target directory (`git init` if needed; branch `main` unless the user chose otherwise):
1. **Start from the tested minimum** for the language: `${CLAUDE_PLUGIN_ROOT}/languages/<lang>/fixture/`
   (typescript, python, rust, cpp) is a minimal project whose gate is executed by the plugin's own
   checks. Copy it, rename the package and sample module to the project's names, replace the sample
   with the first real module stub, keep one real test. Other languages: write the equivalent.
2. **`scripts/ci.sh`** from `${CLAUDE_PLUGIN_ROOT}/templates/scripts/ci.sh`: fill each stage from
   `${CLAUDE_PLUGIN_ROOT}/languages/<lang>/stages.json` (`null` → delete the line; read its `notes`
   before changing a command), then clean it up as `decisions.md` says under *Fill or delete*.
   Add stages the project needs beyond the minimum
   (a linter, integration tests) through the package manager, never a bare binary.
3. **The rest, per the decisions:** CI workflow, `release.sh` + `healthcheck.sh`, `CHANGELOG.md`,
   `.gitignore` from `templates/gitignore/<lang>.gitignore`, `LICENSE` if wanted — see
   `decisions.md` for which file each answer produces.
4. **`CLAUDE.md`** from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template`, every `{{…}}` filled or
   its line deleted. Keep it under ~60 lines: commands Claude cannot guess, deviations from
   defaults, non-obvious traps, the settings block. Nothing a model already does, no process prose,
   no file-by-file map.
5. A `README.md` with what it is and how to run it. No other docs unless the user asked or the
   project has something a reader could not recover from the code.

## 3. Prove it
- Install dependencies (the `install` command from `stages.json`), generate the lockfile, commit it.
- `scripts/ci.sh full` must pass **with at least one test executed** — report the command and the
  test count, not just the exit code. Fix until it does; never weaken a stage to get green.
- A runnable app with a non-trivial launch (a server, a database, env vars): run
  `/run-skill-generator` once where it is available, so `/run`, `/verify` and `deliver`'s
  screenshots can start it; where it is not, put the run command in `CLAUDE.md`.
- Commit (`chore: project setup`), push if a remote exists.

## 4. Report
The decisions, the files created, the gate line (command, checks, tests), and how to start working:
`/wf:spec` to plan, `/wf:deliver` to build, or just ask.
