---
name: resume
description: Continue interrupted work by reconstructing state from the repo — current branch, the in-progress spec, its unchecked subtask boxes, and git log. Works identically in every environment. Use on an AUTO-RESUME directive or when asked to continue.
---

# Resume

Picks up interrupted work. There is no separate checkpoint to trust — **the repo is the state**: the branch tells you which ticket, the spec's unchecked boxes tell you what's left, and `git log` tells you what actually landed. This reconstructs the same way in local, cloud, docker, and VS Code sessions.

## Usage
```
/resume
```

## Instructions

### 1. Find the work
- Current branch: `git branch --show-current` (`{branch}` = with `/`→`-` for the memory filename). A feature branch (`feature/{id}-…`) names the ticket.
- **Ship run?** Check the fixed **`.claude/memory/context-ship.md`** first: a `## Ship` section means a `/ship` orchestration is active — resume it from the first unfinished ticket (may need to switch branches / do a pending merge). A `## Blocked` there → surface it and stop.
- The in-progress spec: the one with `status: in-progress` (search `docs/specs/`), or the one matching the branch id.
- Branch blocker: `.claude/memory/context-{branch}.md` with `## Blocked` → tell the user and stop (don't work around a human-needed blocker).
- If there's no in-progress spec, no ship state, and no branch work: say "nothing in progress", list any `status: ready` specs, and stop.
- **Auto-resume:** if `.claude/memory/settings.md` has `auto_resume: true` and there IS work to continue and this is a cloud session, ensure the recovery heartbeat is armed (idempotent — see `/auto-resume`). This is what re-arms after each firing.

### 2. Reconcile against reality (git wins)
Read the spec's subtask checkboxes and compare to `git log --oneline -15` on this branch. **If they disagree, trust git** and fix the boxes: a subtask with a matching commit is done even if unchecked; an unchecked box with no commit is the next work. This self-corrects a crash mid-subtask.

### 3. Continue
Resume at the **first unchecked subtask** (or the current phase): keep implementing per `/implement`, or if all subtasks are done, run `/verify`, then merge per the Merge policy. For a `/ship` run, continue the orchestration loop. No model/tier to re-arm — the session runs on its normal model; reach for `/consult` only if a hard call comes up.

Any short-lived agent that was mid-run when the session died (a `runner` or `smoke-tester`) simply gets re-run — they're idempotent, there's nothing to recover.

### 4. When done
Finish the ticket (spec → `completed/`), and clear any `## Ship`/`## Blocked` note from the branch memory file once the work is truly complete. If an `auto-resume: {branch}` heartbeat is armed, delete it now — nothing left to recover (the `auto_resume` setting stays on; see `/auto-resume`).
