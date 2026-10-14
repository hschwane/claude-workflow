---
name: deliver
description: Implement one or more specs (or a request) until a fresh-context critic passes them against the spec and the original bar, with the gate green — at most 4 fix rounds per spec, then report what is open. Use when the user asks to deliver, ship or implement specific specs, or when /wf:gauntlet hands over a round of specs.
argument-hint: "<spec ids | issue numbers | request> [bar: <design doc or reference>]"
disable-model-invocation: true
---

# Deliver

Build freely; the discipline is in how the result is checked. Inputs: `$ARGUMENTS`.

## 1. Resolve the work
- **Spec IDs / issue numbers** → read them (spec mode from the `<!-- wf:settings -->` block in
  `CLAUDE.md`; `files`: `docs/specs/`, `issues`: `gh issue view`).
- **A request** → enrich it into a bar with the `spec` skill (enrich mode) and show it before you
  build. Ask only if guessing would change what gets built.
- **The original bar** — the spec's `source` (design doc, reference, the user's words), or what the
  caller passed as `bar:`. Every critic gets it. For UI work, `docs/design/style-guide.md` is part
  of it when it exists.

## 2. Order the work
- **Related specs run one after another in this session**, so later ones build on what earlier ones
  settled. Specs touching the same code form a **batch**: built together, gated once, **judged one
  verdict per spec**.
- **Independent specs** (no shared files) may run in parallel — subagents in isolated worktrees,
  each running sections 3–5 for its spec — only when the user or the caller asked for parallelism.
- After a long group, compact or hand over to a fresh session: the spec statuses are the handoff.

## 3. Build
Set the spec `in-progress` (file frontmatter or issue label). Implement the way you judge best —
tests for what the criteria demand, expected values taken from the spec, never from a run. Commit in
sensible steps (conventional messages). On `git-flow` work on a `feature/<id>` branch; merging and
releasing are not part of delivering unless the user asked.

## 4. Gate and evidence
- Run the gate: `scripts/ci.sh full` if the project has it, otherwise the project's own test and
  build commands. Keep the **full command and its output** — the critic treats missing, red or
  zero-test output as a failure.
- **UI work** (`ui: yes`, or the change is visible on screen): start the app (the project's
  `run` skill or recipe if `/run-skill-generator` made one, else its documented dev command) and
  capture screenshots with Playwright of each screen and state the spec's verification lists —
  including the results of actions — at the style guide's viewports (phone with touch emulation
  where it says touch). Check horizontal overflow against `visualViewport.width`, not `innerWidth`.

## 5. Critic loop
Spawn the plugin's critic agent (`wf:critic`) with: the original bar, the spec, the diff (`git diff <start>..HEAD`), the
gate output, the screenshot paths with what each shows, and on a re-check the previous findings.
Never your reasoning or history.
- **PASS** → set the spec `done`, commit, next spec.
- **FAIL** → fix every must-fix; a *consider* may be declined with a one-line reason. Re-run the
  gate, re-capture, re-judge. A round is one fix plus one complete re-check.
- **Bar questions** go to the user; meanwhile take the least invasive reading and say which.
- **After 4 rounds with must-fixes still open:** stop that spec, leave it `in-progress`, and report
  the open findings with two options: **turn them into new specs**, or **authorise another round**.
  Unattended (called by `gauntlet`), return them to the caller instead of asking.

## 6. Report
Per spec: verdict, rounds used, the gate line (command, tests run), findings fixed / declined (with
reason) / open, commits. Then what is left for the user.
