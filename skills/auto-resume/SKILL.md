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

**What this does and doesn't do.** The heartbeat's one job is to **wake** a cloud session that stalled at the limit — a limit reset does not restart the session on its own, so without it the run just sits dead until you return. It does **not** need to preserve *what Claude was doing*: the heartbeat resumes the **same session**, so the chat history (and the repo — spec checkboxes + git) is still there; the woken agent reads its own context to see what's left. So there's no scratch-note or state-copying machinery — just the wake.

**Covers free chat, not only skills.** Because the wake is all that's needed, the heartbeat should be armed for *any* work, including a plain prompt outside `/implement`/`/ship`. A `UserPromptSubmit` hook (`auto-resume-guard.sh`) does the arming check **script-side**: on each prompt, if `auto_resume: true`, this is a cloud session, and no heartbeat is armed yet (`recovery_trigger:` absent from settings.md), it emits a one-line nudge to arm it — otherwise it stays completely silent (armed → zero cost for the rest of the session). The hook can't create the Routine itself (trigger creation is MCP-only, agent-only), so that single nudge is unavoidable, but it happens at most once per un-armed period, not per prompt. When the heartbeat later fires and the woken agent sees the work is already finished, it deletes the Routine so you're not woken again (and clears `recovery_trigger:`, so the next prompt re-arms).

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
If this is a cloud/remote session, **arm the heartbeat now** (see **Heartbeat** below) so the current session is already covered — don't wait for the next prompt's hook nudge. Print what it does; never ask.

### `off`
Remove the `auto_resume:` line from settings.md. If a heartbeat is armed — a recorded `recovery_trigger:` id, or a `auto-resume: {branch}` Routine found via `list_triggers` — `delete_trigger` it and remove the `recovery_trigger:` line too. Print `Auto-resume OFF.` (Does **not** touch `unsupervised` or the usage threshold.)

### (no argument)
Print the `auto_resume` state from settings.md and whether a `auto-resume: {branch}` heartbeat Routine is currently armed (`list_triggers`).

## Heartbeat — the cloud recovery mechanism
A recurring Routine bound to this session. A hard kill can't remove it, so it fires after the limit resets and pokes the agent back to life. It's armed whenever `auto_resume: true` and a prompt comes in unarmed (the hook), and it self-deletes the first time it fires and finds nothing left to do — the *setting* stays on, so the next prompt re-arms it. It is **not** tied to unsupervised mode.

**Arm** — only in a cloud/remote session (the `mcp__Claude_Code_Remote__create_trigger` tool is available / `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE` is set). Idempotent: check `list_triggers` for a `auto-resume: {branch}` Routine bound to this session; if absent, create a recurring Routine (cron `{minute} * * * *` from `date +%M`) with the prompt below, and record `recovery_trigger: {id}` in settings.md. `{branch}` = the git branch with every `/` replaced by `-`.
```
Auto-resume heartbeat: you were woken to continue after a possible limit stall. Look at the
conversation context AND the repo (context-ship.md for a ## Ship run, any in-progress spec + its
unchecked boxes, ## Blocked notes) and decide:
  - Work still unfinished → continue it, in whatever mode settings.md sets. For spec/ship work run
    /resume. unsupervised: true → apply the autonomous defaults and keep going; supervised
    (default) → do the mechanical work and, when a real decision is needed, write a ## Blocked note
    with the question and stop. Leave this Routine armed.
  - Nothing left to do (the context shows the task finished, or a ## Blocked note is present)
    → delete this Routine (find it via list_triggers by name) and remove the recovery_trigger:
    line from settings.md, so you aren't woken again. The next prompt re-arms it.
  - Still rate-limited / can't proceed → stop; the next hourly firing retries.
Do all of this silently unless you're producing real work output.
```

**Teardown:** when the work is done or a `## Blocked` note is written, `delete_trigger` the Routine **and remove the `recovery_trigger:` line** from settings.md (so a later prompt re-arms cleanly). On `/auto-resume off`, same teardown. **Leave `auto_resume: true`** — it's a standing preference.

**Local / VS Code / docker:** no Routine (nothing survives a killed process there). Auto-resume in those environments = the SessionStart hook (or `scripts/claude-loop.sh`) drives `/resume` on the next start. A fully-killed local process still needs `claude-loop.sh` running, or you reopening the session, to come back — that is the one honest environment limit; the heartbeat closes it only in cloud.
