---
name: unsupervised
description: Toggle unsupervised mode — no interactive questions, autonomous defaults, optional token-budget threshold with automatic in-session pause/resume
argument-hint: "on [threshold%] | off"
disable-model-invocation: true
---

# Unsupervised Mode

Enables or disables unsupervised mode. In unsupervised mode Claude never asks interactive questions, uses autonomous defaults for every decision, keeps working until the task is done (the Stop hook blocks premature stops), and writes a `## Blocked` section to the branch context file (`.claude/memory/context-{branch}.md`) if it hits a genuine blocker.

Optionally, a **usage threshold** caps how much of the rate limit unsupervised work may consume: when the session (5h) or weekly (7d) usage reaches the threshold, Claude pauses **inside the same session** and automatically continues once usage drops below the threshold again (the 5h window slides). This keeps headroom for your own interactive use and works in the terminal and the VS Code extension alike — no external scripts, no lost context, same console.

## Usage
```
/unsupervised on         # enable, no usage cap
/unsupervised on 80      # enable, pause at 80% of session or weekly limit
/unsupervised off        # disable — restores normal interactive behavior
/unsupervised            # show current status + usage
```

## Instructions

### If `on [threshold]`

Parse the optional threshold (integer 10-99; values like "80%" → 80). Write to `.claude/memory/settings.md` (create the file if missing; replace existing `unsupervised`/`usage_threshold` lines):

```markdown
# Runtime Settings
unsupervised: true
usage_threshold: {threshold}    ← only if a threshold was given
```

**Then arm the cloud recovery heartbeat** (see "Cloud/remote auto-recovery heartbeat" below). Only in a cloud/remote session — detect it by the `mcp__Claude_Code_Remote__create_trigger` tool being available (equivalently, env `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE` is non-empty). In a local terminal or VS Code session, skip this — `claude-loop.sh` or the human restarts instead. Arming is idempotent: do it now so the safety net exists before any work starts.

Print:

```
Unsupervised mode ON{, usage cap {threshold}%}.

Claude will:
  ✓ Never use AskUserQuestion
  ✓ Apply autonomous defaults (see below)
  ✓ Keep working: the Stop hook blocks premature stops while "## In Progress" exists
  {✓ Pause at {threshold}% — loop sessions stop cleanly for restart; interactive terminal/VS Code sessions wait in-session until below {threshold-20}%}
  {✓ Cloud/remote: recovery heartbeat armed (hourly Routine) — if this session is
     killed by the rate limit or a crash, the heartbeat resumes it from the
     checkpoint once the limit clears, and self-deletes when work is done}
  ✓ Write "## Blocked" to the branch context file if human input is genuinely required
  ✓ Clear "## In Progress" when complete

Autonomous defaults:
  /refine       — fully-autonomous, auto-accept results
  /implement    — proceed immediately, no confirmation steps
  /pr           — auto-merge (squash) after green CI + reviews
  /brainstorm   — generate ideas, auto-create drafts for top suggestions
  /prioritize   — accept the product-owner's recommended slate (never archives specs)
  /release      — requires bump type as argument (/release patch|minor|major)
  /commit       — auto-fix linter issues, commit without confirmation
  model/effort  — never asked; per-ticket routing from the spec applies
                  automatically (route skills re-arm from the checkpoint's
                  tier line on every wake — see /resume)

💡 Before you walk away: set the session to Sonnet (/model sonnet).
  The workflow elevates itself per ticket via route skills (refinement and
  reviews run on Opus or the top tier automatically); a pricier session
  model only raises the cost of orchestration and CI waits, not quality.

Blockers that will STOP the work (require human attention):
  - Merge conflict that cannot be auto-resolved
  - Breaking change that affects public API
  - Missing credentials / secret not in environment
  - CI failure not fixable after 3 attempts
  - Any ambiguity that cannot be resolved from docs or code

Start a task and leave the session open:
  /implement FEAT-001     (or /refine, /pr, ...)

If the session dies anyway (crash, hard rate limit):
  - Cloud/remote: nothing to do — the recovery heartbeat resumes it automatically
    once the limit clears (hourly), then self-deletes when the work is done.
  - Terminal/VS Code: just reopen it — the SessionStart hook auto-resumes from the
    checkpoint. For fully headless terminal operation there is also ./scripts/claude-loop.sh
```

### If `off`

Remove the `unsupervised: true` and `usage_threshold:` lines from `.claude/memory/settings.md` (delete the file if nothing else remains). Remove `.claude/memory/usage-wait.active` if present.

**Disarm the recovery heartbeat** if one is armed: read `recovery_trigger:` from `.claude/memory/settings.md` (or find it via `mcp__Claude_Code_Remote__list_triggers` by the name `unsupervised-recovery: {branch}` bound to this session) and delete it with `mcp__Claude_Code_Remote__delete_trigger`. Remove the `recovery_trigger:` line.

Print: `Unsupervised mode OFF. Claude will ask questions normally.{ Recovery heartbeat disarmed.}`

### If no argument

Read `.claude/memory/settings.md` and print whether unsupervised mode is on and which threshold is set. Then run `bash .claude/hooks/usage-guard.sh --status` and show the output (current 5h/7d usage).

---

## Behavior When Unsupervised Mode is Active

(This behavior is anchored in the project CLAUDE.md "Session Behavior" section, which is always loaded; the Stop hook and usage-guard hook enforce it.)

When `.claude/memory/settings.md` contains `unsupervised: true`:

**Never** call `AskUserQuestion`. For every question you would normally ask, use the autonomous default listed above.

**Usage threshold pause** — when a hook message reports `USAGE THRESHOLD REACHED`:
1. Finish or commit only the current atomic step (never leave the working tree broken)
2. Update the checkpoint in the branch context file (`.claude/memory/context-{branch}.md`)
3. Determine which applies, in order:
   - **`.claude/memory/loop-mode.marker` present** (session started by `claude-loop.sh`): **stop the session** — the loop restarts it with a fresh context window and resumes from the checkpoint automatically.
   - **Cloud/remote session** (the recovery heartbeat is armed — `mcp__Claude_Code_Remote__*` tools available): just **checkpoint and end the turn.** Do not try to schedule your own one-shot wakeup and do not poll — the standing hourly heartbeat (below) resumes the work once usage clears. Ending cleanly here also means that if the limit instead hard-kills the session mid-turn, the heartbeat still recovers it. (Note: in a cloud session the `USAGE THRESHOLD REACHED` hook usually never fires — the guard can't read usage there, see below — so in practice the session is simply killed and the heartbeat brings it back. The heartbeat is the load-bearing mechanism, not this hook.)
   - **Neither applies** (interactive VS Code / terminal session with no scheduling tool): run `bash .claude/hooks/usage-guard.sh --wait` via Bash (3-minute timeout per call) repeatedly until it prints `RESUME_OK`, then continue working from the checkpoint.

## Cloud/remote auto-recovery heartbeat

**Why:** in Claude Code cloud/remote sessions the usage-guard **cannot read the rate limit** (no `~/.claude/.credentials.json` — the token is on a file descriptor — and no statusline cache), so it fails open and never pauses. The session therefore runs straight into the hard limit and is **killed mid-work**, and a one-shot `send_later`/`ScheduleWakeup` doesn't bring it back (it fires once; if usage is still capped, or the session was killed before it could re-arm, the chain is dead). The fix is a **standing recurring Routine** that is armed once, server-side, and keeps firing on its own schedule — so it survives a hard kill and resumes the work after the limit resets.

**Arm** (from `/unsupervised on`, cloud/remote only; idempotent):
1. `{branch}` = `git branch --show-current | sed 's|/|-|g'`. Check `mcp__Claude_Code_Remote__list_triggers` for one named `unsupervised-recovery: {branch}` already bound to this session — if it exists, do nothing.
2. Otherwise create it with `mcp__Claude_Code_Remote__create_trigger` (default binding = this session, so it resumes this conversation with its context and connectors intact):
   - `name`: `unsupervised-recovery: {branch}`
   - `cron_expression`: `{M} * * * *` where `{M}` = `date +%M` (fires hourly, offset to arm time; hourly is the platform minimum and is fine — rate limits reset on multi-hour boundaries)
   - `prompt`: the self-contained recovery instruction below
3. Record the returned trigger id as a `recovery_trigger: {id}` line in `.claude/memory/settings.md` (for idempotency and `/unsupervised off`).

**Heartbeat prompt** (must be self-contained — it may fire into a cold-resumed session):
```
Unsupervised auto-recovery heartbeat for branch {branch}. Do this silently — do NOT
message the user for a routine resume or a no-op firing:
1. Read .claude/memory/context-{branch}.md.
2. If it has a `## Blocked` section → the work is intentionally stopped for a human.
   Delete this recovery Routine (find it via list_triggers by name
   'unsupervised-recovery: {branch}') and stop.
3. Else if it has `## In Progress` → run /resume to continue (re-arms the tier and
   recovers any crashed subagents). If you cannot proceed because usage is still
   rate-limited, stop without changes — the next hourly firing will retry.
4. Else (no `## In Progress`) → the work is complete. Delete this recovery Routine and stop.
5. Safety valve: if three consecutive heartbeats resume but produce no new commits
   (compare `git log --oneline -5` to the checkpoint's last_completed), write a
   `## Blocked` note ("auto-recovery made no progress across 3 firings"), delete this
   Routine, and stop — so a stuck task can't loop forever.
```

**Disarm:** the heartbeat self-deletes when work completes or blocks (steps 2/4/5 above). `/unsupervised off` also deletes it. **Any skill that clears `## In Progress` on completion in a cloud unsupervised session must also delete this Routine** (belt-and-suspenders — see the CLAUDE.md "Session Behavior" completion rule).

**For genuine blockers only** — write to the branch context file (`.claude/memory/context-{branch}.md`) ABOVE the `## In Progress` section:

```markdown
## Blocked
reason: Merge conflict in src/auth/session.ts — cannot auto-resolve
requires: Manual merge decision
saved_at: 2026-06-10T15:00:00Z
```

Then stop. Do not clear `## In Progress`. In a cloud/remote session, also **delete the recovery heartbeat** (a blocker needs a human, not hourly retries).

**When all work is complete** — clear the `## In Progress` section from the branch context file, **delete the recovery heartbeat** if one is armed (cloud/remote), and stop.
