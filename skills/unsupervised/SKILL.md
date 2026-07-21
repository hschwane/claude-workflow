---
name: unsupervised
description: Toggle unsupervised mode — no interactive questions, autonomous defaults, keep working until done, with a proactive pause at a usage threshold (default 90%) where usage is readable. Independent of /auto-resume.
argument-hint: "on [threshold%] | off"
disable-model-invocation: true
---

# Unsupervised Mode

In unsupervised mode Claude never asks questions, applies autonomous defaults, and keeps working until the task is done or genuinely blocked. State lives in the repo, so an interrupted run resumes cleanly anywhere.

**Independent of `/auto-resume`.** Unsupervised = *how* Claude works (no questions, proactive pause near the limit). Auto-resume = *whether* an interrupted run wakes itself after the limit resets. They are separate toggles — flipping one never changes the other. Turn on `/auto-resume` if you want an unsupervised run to finish itself across limit resets while you're away.

## Usage
```
/unsupervised on          # enable (proactive pause at 90% where usage is readable)
/unsupervised on 80       # enable, pause at 80%
/unsupervised off
/unsupervised             # show status + usage
```

## Instructions

### `on [threshold]`
Write to `.claude/memory/settings.md` (create if missing; default threshold 90; leave any `auto_resume:` line untouched):
```
unsupervised: true
usage_threshold: {threshold or 90}
```
Print what it will do (never ask): the autonomous defaults below, and the proactive pause at the threshold where usage is readable. Mention that auto-resume is separate — suggest `/auto-resume on` if the user wants an interrupted run to wake itself.

### `off`
Remove the `unsupervised:` / `usage_threshold:` lines from settings.md. Print `Unsupervised mode OFF.` **Does not touch `auto_resume` or any heartbeat** — auto-resume is toggled only via `/auto-resume`.

### (no argument)
Print unsupervised state + threshold from settings.md, then `bash .claude/hooks/usage-guard.sh --status`.

## Autonomous defaults (when `unsupervised: true`)
- **Never** ask the user — apply the most reasonable default and note assumptions.
- `/plan` — reasonable defaults for open questions, noted in the spec; default to in-scope.
- `/implement` — proceed through subtasks; `/consult` when genuinely stuck rather than asking.
- **Merge** — local git per the Merge policy (no PR).
- `/release` — needs the bump type as an argument (`/ship … minor` or `/release minor`).
- **Blocker** (merge conflict unresolvable, missing credentials, unresolvable ambiguity) → write `## Blocked` (reason + what's required) to `.claude/memory/context-{branch}.md` and stop.
- **Done** → clear `## Ship`/`## Blocked` notes and post a short final report (what shipped, anything deferred, anything blocked) so you can see what happened on return.

## Pause behavior
- **Where usage is readable** (local terminal / VS Code): the usage-guard hook fires at the threshold (default 90%) → finish the atomic step, commit, end the turn; resume when usage recovers (automatically if `/auto-resume` is on, otherwise on the next session).
- **Where it isn't** (cloud/docker): no proactive pause — the session runs into the hard limit. If `/auto-resume` is on, the heartbeat resumes it after reset; repo-as-checkpoint caps the loss at the current subtask.

> Supervised mode (unsupervised off) has **no** proactive pause — Claude works to the hard limit and, if `/auto-resume` is on, continues after the reset.
