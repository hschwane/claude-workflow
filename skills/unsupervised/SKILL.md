---
name: unsupervised
description: Toggle unsupervised mode — no interactive questions, autonomous defaults, keep working until done. Pauses at a usage threshold where usage is readable; arms a recovery heartbeat in cloud sessions.
argument-hint: "on [threshold%] | off"
disable-model-invocation: true
---

# Unsupervised Mode

In unsupervised mode Claude never asks questions, applies autonomous defaults, and keeps working until the task is done or genuinely blocked. State lives in the repo, so an interrupted run resumes cleanly anywhere.

## Usage
```
/unsupervised on          # enable (pause at 80% where usage is readable)
/unsupervised on 70       # enable, pause at 70%
/unsupervised off
/unsupervised             # show status + usage
```

## Instructions

### `on [threshold]`
Write to `.claude/memory/settings.md` (create if missing; default threshold 80):
```
# Runtime Settings
unsupervised: true
usage_threshold: {threshold or 80}
```
**If this is a cloud/remote session** (the `mcp__Claude_Code_Remote__create_trigger` tool is available / `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE` is set): arm the **recovery heartbeat** — one recurring Routine so a rate-limit kill or crash is recovered automatically. Idempotent: check `list_triggers` for `unsupervised-recovery: {branch}` bound to this session; if absent, create it (cron `{minute} * * * *` from `date +%M`) with this prompt, and record its id as `recovery_trigger: {id}` in settings.md:
```
Unsupervised auto-recovery heartbeat for branch {branch}. Silently: read
.claude/memory/context-{branch}.md and the in-progress spec. If a ## Blocked section
exists → delete this Routine (find via list_triggers by name) and stop. If in-progress
work remains → /resume. If nothing remains → delete this Routine and stop. If still
rate-limited and you can't proceed → stop; the next hourly firing retries.
```
Skip the heartbeat in local/VS Code/docker sessions (the session-start hook + user, or `claude-loop.sh`, handle restart there).

Print what it will do (never ask; autonomous defaults; pause behavior; heartbeat armed if cloud) and the autonomous defaults below.

### `off`
Remove the `unsupervised:`/`usage_threshold:` lines from settings.md. If a `recovery_trigger:` id is recorded (or a `unsupervised-recovery: {branch}` Routine exists), `delete_trigger` it and remove the line. Print `Unsupervised mode OFF.`

### (no argument)
Print unsupervised state + threshold from settings.md, then `bash .claude/hooks/usage-guard.sh --status`.

## Autonomous defaults (when `unsupervised: true`)
- **Never** use `AskUserQuestion` — apply the most reasonable default and note assumptions.
- `/plan` — reasonable defaults for open questions, noted in the spec; default to in-scope.
- `/implement` — proceed through subtasks; `/consult` when genuinely stuck rather than asking.
- **Merge** — local git per the Merge policy (no PR).
- `/release` — needs the bump type as an argument (`/ship … minor` or `/release minor`).
- **Blocker** (merge conflict unresolvable, missing credentials, unresolvable ambiguity) → write `## Blocked` (reason + what's required) to `.claude/memory/context-{branch}.md` and stop; in cloud, also delete the recovery heartbeat.
- **Done** → clear `## Ship`/`## Blocked` notes; in cloud, delete the recovery heartbeat.

## Pause behavior
- **Where usage is readable** (local terminal / VS Code): the usage-guard hook fires at the threshold → finish the atomic step, commit, end the turn; resume when usage recovers.
- **Where it isn't** (cloud/docker): no pause — the session runs into the limit and the heartbeat resumes it after reset. Repo-as-checkpoint caps the loss at the current subtask.
