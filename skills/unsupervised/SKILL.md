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

Print:

```
Unsupervised mode ON{, usage cap {threshold}%}.

Claude will:
  ✓ Never use AskUserQuestion
  ✓ Apply autonomous defaults (see below)
  ✓ Keep working: the Stop hook blocks premature stops while "## In Progress" exists
  {✓ Pause at {threshold}% — loop sessions stop cleanly for restart; cloud/remote sessions schedule a wakeup and go idle; interactive terminal/VS Code sessions wait in-session until below {threshold-20}%}
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
  model tier    — never asked; your session model applies throughout

💡 Before you walk away, consider: /model opusplan
  Unsupervised mode skips the per-run model-tier question and applies your
  session model to everything. opusplan (Opus plans, Sonnet executes) gives
  strong planning at lower usage-limit consumption than running all on Opus.

Blockers that will STOP the work (require human attention):
  - Merge conflict that cannot be auto-resolved
  - Breaking change that affects public API
  - Missing credentials / secret not in environment
  - CI failure not fixable after 3 attempts
  - Any ambiguity that cannot be resolved from docs or code

Start a task and leave the session open:
  /implement FEAT-001     (or /refine, /pr, ...)

If the session dies anyway (crash, hard rate limit): just reopen it — the
SessionStart hook auto-resumes from the checkpoint. For fully headless
operation in a terminal there is also: ./scripts/claude-loop.sh
```

### If `off`

Remove the `unsupervised: true` and `usage_threshold:` lines from `.claude/memory/settings.md` (delete the file if nothing else remains). Remove `.claude/memory/usage-wait.active` if present.

Print: `Unsupervised mode OFF. Claude will ask questions normally.`

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
3. Determine which of these three applies, in order:
   - **`.claude/memory/loop-mode.marker` present** (session started by `claude-loop.sh`): **stop the session** — the loop restarts it with a fresh context window and resumes from the checkpoint automatically.
   - **A schedule-a-future-message tool is available** (e.g. `send_later` from the Claude Code Remote MCP server, or `ScheduleWakeup` if this session was started by `/loop`) — this is a cloud/remote session (Claude Code on the web, or any managed session without an attached interactive terminal): **do not poll with a Bash sleep loop.** Instead:
     1. Run `bash .claude/hooks/usage-guard.sh --check` once (no retry).
     2. If it prints `RESUME_OK`, continue working immediately.
     3. Otherwise schedule a wakeup 20–30 minutes out with a message like "Resume checkpointed unsupervised work — recheck usage threshold" (`send_later`/`ScheduleWakeup`), then end the turn so the session goes idle. When the wakeup fires, repeat from step 3.1.
     - Never call `usage-guard.sh --wait` here — its internal retry/sleep loop is built for a locally-attached terminal and will burn turns or run into session limits in a cloud session instead of actually waiting.
   - **Neither applies** (interactive VS Code / terminal session with no scheduling tool): run `bash .claude/hooks/usage-guard.sh --wait` via Bash (3-minute timeout per call) repeatedly until it prints `RESUME_OK`, then continue working from the checkpoint.

**For genuine blockers only** — write to the branch context file (`.claude/memory/context-{branch}.md`) ABOVE the `## In Progress` section:

```markdown
## Blocked
reason: Merge conflict in src/auth/session.ts — cannot auto-resolve
requires: Manual merge decision
saved_at: 2026-06-10T15:00:00Z
```

Then stop. Do not clear `## In Progress`.

**When all work is complete** — clear the `## In Progress` section from the branch context file and stop.
