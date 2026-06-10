---
name: unsupervised
description: Toggle unsupervised mode — no interactive questions, autonomous defaults, loop-safe blocker handling
argument-hint: "on|off"
disable-model-invocation: true
---

# Unsupervised Mode

Enables or disables unsupervised mode. In unsupervised mode Claude never asks interactive questions, uses autonomous defaults for every decision, and writes a `## Blocked` section to `.claude/memory/context.md` if it hits a genuine blocker (instead of waiting for user input). An external loop script (`scripts/claude-loop.sh`) restarts the session automatically after rate limit resets.

## Usage
```
/unsupervised on     # enable — do this before starting a task, then run the loop
/unsupervised off    # disable — restores normal interactive behavior
/unsupervised        # show current status
```

## Instructions

### If `on`

Write the following block to `.claude/memory/settings.md` (create the file if missing, overwrite the `unsupervised` line if it exists):

```markdown
# Runtime Settings
unsupervised: true
```

Print:

```
Unsupervised mode ON.

Claude will:
  ✓ Never use AskUserQuestion
  ✓ Apply autonomous defaults (see below)
  ✓ Write "## Blocked" to context.md if human input is genuinely required
  ✓ Clear "## In Progress" when complete
  ✓ Keep working: the Stop hook blocks premature stops while "## In Progress" exists

Autonomous defaults:
  /refine       — fully-autonomous, auto-accept results
  /implement    — proceed immediately, no confirmation steps
  /pr           — auto-merge (squash) after green CI + reviews
  /brainstorm   — generate ideas, auto-create drafts for top suggestions
  /prioritize   — accept the product-owner's recommended slate (never archives specs)
  /release      — requires bump type as argument (/release patch|minor|major)
  /commit       — auto-fix linter issues, commit without confirmation

Blockers that will STOP the loop (require human attention):
  - Merge conflict that cannot be auto-resolved
  - Breaking change that affects public API
  - Missing credentials / secret not in environment
  - CI failure not fixable after 3 attempts
  - Any ambiguity that cannot be resolved from docs or code

To start supervised automation:
  1. Start a task:  /implement FEAT-001   (or /refine, /pr, etc.)
  2. In a terminal: ./scripts/claude-loop.sh [reset-minutes]
  3. Walk away. The loop auto-resumes after each rate limit reset.
  4. Check back: tail -f .claude/memory/unsupervised.log

To stop at any time: Ctrl+C in the terminal running claude-loop.sh
```

### If `off`

Remove the `unsupervised: true` line from `.claude/memory/settings.md` (or delete the file if that was the only line).

Print: `Unsupervised mode OFF. Claude will ask questions normally.`

### If no argument

Read `.claude/memory/settings.md`. Print whether unsupervised mode is currently on or off.

---

## Behavior When Unsupervised Mode is Active

(This behavior is anchored in the project CLAUDE.md "Session Behavior" section, which is always loaded; additionally the Stop hook blocks premature stops while unsupervised mode is on.)

When `.claude/memory/settings.md` contains `unsupervised: true`:

**Never** call `AskUserQuestion`. For every question you would normally ask, use the autonomous default listed above.

**For genuine blockers only** — write to `.claude/memory/context.md` ABOVE the `## In Progress` section:

```markdown
## Blocked
reason: Merge conflict in src/auth/session.ts — cannot auto-resolve
requires: Manual merge decision
saved_at: 2026-06-10T15:00:00Z
```

Then stop. Do not clear `## In Progress`. The `claude-loop.sh` script will detect `## Blocked`, print the reason, and exit so you can handle it.

**When all work is complete** — clear the `## In Progress` section from `.claude/memory/context.md`. The loop detects its absence and exits cleanly.
