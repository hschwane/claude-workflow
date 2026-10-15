---
name: onboard
description: Bring an existing project that has never used the wf plugin under the workflow — understand the codebase, interview the user, fit a real gate to the project's own commands, and record the decisions. Use when the user asks to onboard or adopt the workflow. For projects that carry an older version of this plugin, use /wf:convert instead.
argument-hint: "[path]"
---

# Onboard

An existing codebase has opinions; fit the workflow to them, never the other way round. If the
project contains `.claude/workflow-source.json`, `.claude/guidelines/`, `docs/workflow/` or a
`workflow-settings` block, it carries an older version of this plugin: stop and use `/wf:convert`.

**Lead and workers** (`${CLAUDE_PLUGIN_ROOT}/shared/workers.md`): understanding (section 1) and fitting plus proving
(sections 3–4) go to workers — in a Project, threads —; the summary and the interview stay with you.

## 1. Understand
Explore with a worker so the reading stays out of this context: stack, how it is built, run and
tested (the real command names in `package.json`/`pyproject.toml`/`Cargo.toml`/`Makefile`), CI,
how it is released and deployed, whether it has a UI and a design document, existing docs and
`CLAUDE.md`. Report it back in a short summary and show it to the user.

## 2. Interview
Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/decisions.md`. Ask only what applies and is not already
answered by the code; pre-fill what you found and ask the user to confirm. One batch, plain chat.

## 3. Fit, don't replace
- **Gate:** `scripts/ci.sh` from `${CLAUDE_PLUGIN_ROOT}/templates/scripts/ci.sh`, each stage filled
  with **this project's own commands**, through its package manager. A missing stage (no typecheck
  script) → add a script to the manifest rather than a bare binary, and say so. A failing existing
  command is a pre-existing break: show it and propose the smallest fix — agreed by the user, or,
  when nobody can be asked, done and reported as not agreed.
- **Caches the new stages create** (`.ruff_cache/`, `.pytest_cache/`, `dist/`, …) are appended to
  `.gitignore` under a dated comment.
- **Existing CI:** offer to replace its check steps with `bash scripts/ci.sh full`, keeping its
  name, triggers, matrix and deploy jobs. Declined → say in `CLAUDE.md` that CI and the gate differ.
  No CI and the user wants one → install it as in `decisions.md`.
- **`CLAUDE.md`:** keep what the project wrote; add the settings block, the gate commands and the
  `guidelines` line from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template`. Do not rewrite
  hand-written content; if it is far over ~200 lines, propose cuts (what Claude can derive from the
  code) and let the user decide.
- **An existing design system or style guide** → move it to `docs/design/style-guide.md` and fix
  links to it. None → create nothing.
- **Runnable app** with a non-trivial launch → `/run-skill-generator` once where it is available;
  otherwise the run command goes into `CLAUDE.md`.

## 4. Prove it
`scripts/ci.sh full` green **with at least one test executed** — report the command and the counts.
If it cannot be made green, stop and report what blocks it instead of committing a red gate.
Commit (`chore: adopt wf workflow`), on a branch if the user works with branches.

## 5. Report
What you found, the decisions, every file created or changed (and anything you changed in the
project's own manifest or code, marked agreed / not agreed), the gate line.
