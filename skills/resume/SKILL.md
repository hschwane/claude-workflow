---
name: resume
description: Continue interrupted work — reconstructs state from the repo (branch, in-progress spec, its unchecked boxes, git log). Run on an AUTO-RESUME directive, an auto-resume heartbeat wake, or when asked to continue.
---

# Resume

The repo is the state — there is no checkpoint to trust. Only the non-obvious parts are below; the lifecycle, merge policy and memory-file layout are in `CLAUDE.md`.

## Instructions

### 1. Find the work — ship state first
Check `.claude/memory/context-ship.md` **before** the branch. A `## Ship` section means an orchestration is active: continue from its **first unfinished ticket**, which may mean switching branches or completing a pending merge — the current branch is not the answer. Otherwise: the spec with `status: in-progress` (search `docs/specs/`), or the one matching the branch's ticket id.

A `## Blocked` note (in `context-ship.md` or `context-{branch}.md`) → surface it and stop.

Nothing in progress anywhere → say so, list `status: ready` specs, tear down an armed heartbeat (per `/auto-resume`), stop.

### 2. Reconcile — git wins
Compare the spec's checkboxes against `git log --oneline -15` on this branch. **On disagreement, trust git:** a subtask with a matching commit is done even if unchecked; an unchecked box with no commit is the next work. This is what self-corrects a crash mid-subtask.

### 3. Continue
Resume at the first unchecked subtask per `/implement`; if all are done, `/verify`, then `/pr` (or `/release` under `main-only`, where landing on the trunk is the release). For a ship run, continue the orchestration loop.

An agent that died mid-run (`runner`, `smoke-tester`) is simply re-run — they're idempotent, there's nothing to recover.

### 4. Heartbeat
If `.claude/memory/local-settings.md` has `auto_resume: true` and this is a cloud session with work to continue, ensure the heartbeat is armed (idempotent — see `/auto-resume`); this is what re-arms it after each firing. Tear it down when the work completes or a `## Blocked` note is written.
