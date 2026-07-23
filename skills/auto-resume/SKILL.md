---
name: auto-resume
description: Toggle auto-resume — after a session/rate-limit kill or crash, Claude automatically wakes once the limit resets and continues the in-progress work from the repo state. Independent of /unsupervised; works in supervised and unsupervised alike.
argument-hint: "on | off"
disable-model-invocation: true
---

# Auto-resume (recover after a limit)

Independent of `/unsupervised`. When ON, an interrupted run (rate-limit / session-limit kill, crash) is picked back up **automatically** once the limit resets — Claude continues the in-progress work from the repo state, no manual restart. Toggling `/unsupervised` on or off never touches this, and this never changes whether Claude asks questions.

- **Supervised + auto-resume on:** you still get asked questions as normal; work runs to the hard limit, then resumes after reset and continues the mechanical work until done — or until a real decision is needed, at which point it records `## Blocked` with the question so you see it when you're back.
- **Unsupervised + auto-resume on:** fully autonomous to completion, recovered across limit resets, with a short final report at the end.

**What this does and doesn't do.** The heartbeat's one job is to **wake** a cloud session that stalled at the limit — a limit reset does not restart the session on its own, so without it the run just sits dead until you return. It does **not** need to preserve *what Claude was doing*: the heartbeat resumes the **same session**, so the chat history (and the repo — spec checkboxes + git) is still there. That's why there's no per-prompt reminder or scratch-note machinery — it would only re-describe state the resumed session already has. A plain manual prompt (not routed through a skill) simply isn't separately checkpointed; if you want a long ad-hoc run to survive even a *fresh* session, route it through `/ship` or turn on `/unsupervised` so it's spec-tracked. Genuine context loss (a brand-new session with no history) only recovers cleanly for spec/`/ship` work, from the repo.

## Usage
```
/auto-resume on
/auto-resume off
/auto-resume            # show status
```

## Instructions

### `on`
Write to `.claude/memory/settings.md` (create if missing; leave any `unsupervised:`/`usage_threshold:` lines untouched):
```
auto_resume: true
```
If in-progress work exists right now (an in-progress spec, or a `## Ship` note in `context-ship.md`) **and** this is a cloud/remote session, **arm the heartbeat immediately** (see **Heartbeat** below). Print what it does; never ask.

### `off`
Remove the `auto_resume:` line from settings.md. If a heartbeat is armed — a recorded `recovery_trigger:` id, or a `auto-resume: {branch}` Routine found via `list_triggers` — `delete_trigger` it and drop the line. Print `Auto-resume OFF.` (Does **not** touch `unsupervised` or the usage threshold.)

### (no argument)
Print the `auto_resume` state from settings.md and whether a `auto-resume: {branch}` heartbeat Routine is currently armed (`list_triggers`).

## Heartbeat — the cloud recovery mechanism
A recurring Routine bound to this session. A hard kill can't remove it, so it fires after the limit resets and continues the work. It exists only while there is work to protect **and** `auto_resume: true`; it self-deletes when the work is done or blocked — the *setting* stays on, so the next task re-arms it. It is **not** tied to unsupervised mode.

**Arm** — only in a cloud/remote session (the `mcp__Claude_Code_Remote__create_trigger` tool is available / `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE` is set). Idempotent: check `list_triggers` for a `auto-resume: {branch}` Routine bound to this session; if absent, create a recurring Routine (cron `{minute} * * * *` from `date +%M`) with the prompt below, and record `recovery_trigger: {id}` in settings.md. `{branch}` = the git branch with every `/` replaced by `-`.
```
Auto-resume heartbeat. Silently run /resume, which reconstructs state from the repo:
context-ship.md (a ## Ship run spans branches), any in-progress spec + its unchecked boxes,
and ## Blocked notes. Continue the work in whatever mode settings.md sets:
  - unsupervised: true  → apply the autonomous defaults, keep going.
  - supervised (default) → do the mechanical work; when a real decision is needed, write a
    ## Blocked note with the question and stop (the user will answer on return).
On a ## Blocked note, or when everything is done → delete this Routine (find it via
list_triggers by name) and stop. If still rate-limited and you can't proceed → stop; the next
hourly firing retries.
```

**Teardown:** delete the Routine when the work is done or a `## Blocked` note is written (nothing left to recover), and on `/auto-resume off`. **Leave `auto_resume: true` in settings.md** — it's a standing preference; the next run re-arms.

**Local / VS Code / docker:** no Routine (nothing survives a killed process there). Auto-resume in those environments = the SessionStart hook (or `scripts/claude-loop.sh`) drives `/resume` on the next start. A fully-killed local process still needs `claude-loop.sh` running, or you reopening the session, to come back — that is the one honest environment limit; the heartbeat closes it only in cloud.
