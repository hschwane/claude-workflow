---
name: ship
description: "The one orchestrator — turn a spec list or a topic/direction into a shipped version. Plans the tickets (batching every question up front), then autonomously implements, verifies, merges locally, and releases, ending with a report."
argument-hint: "[TICKET-ID ...] | \"topic / direction\" | [patch|minor|major]"
---

# Ship

One command from intent to release. Give it **specific tickets**, a **topic/direction**, or both. It plans, asks everything it needs **once up front**, then runs the whole cycle autonomously and reports what it did.

## Usage
```
/ship FEAT-001 FEAT-003            # ship exactly these
/ship "harden auth and add rate limiting"   # derive tickets from a direction
/ship FEAT-001 "and improve the error messages" minor
```

## Instructions

### 0. Setup — resolve the work list
Parse args: **ticket IDs** (`LETTERS-NUMBER`), a **bump type** (`patch|minor|major`, default `minor`), and any remaining **free text** as a topic/direction.

Build the ticket list:
- **IDs given** → those (validate each exists in `docs/specs/backlog/` or `ready/`; a missing ID stops with a clear message). Preserve the given order = priority order.
- **Topic/direction given** → derive tickets from it: read `docs/VISION.md` + the backlog, propose a small concrete set of tickets (as `/draft` entries), and include any existing backlog items that fit. No separate brainstorm/prioritize step — this is that step, inline.
- **Both** → the IDs plus tickets derived from the text.

Confirm the resolved list with the user (unless unsupervised). This is the one place a spec list becomes concrete.

Be on the integration branch (`develop` if it exists, else `main`/`master`) — if on a feature branch, stop and say so.

### 1. Plan — all questions up front
Run `/plan` **once with every ticket** that isn't already `ready` (skip ones already in `docs/specs/ready/`). This batches all `[USER]` questions across all tickets into a single round at the start. Answer them (unsupervised: reasonable defaults, noted). After this point the run is autonomous — the user can walk away.

Record the resolved plan (ticket order + the batched answers) in **`.claude/memory/context-ship.md`** under `## Ship` — a **fixed, branch-independent** file, because a ship run spans many feature branches. This is the only orchestration state kept (per-ticket detail lives in the specs). Update it as tickets complete; delete it (or clear `## Ship`) when the whole run is done or write `## Blocked` there on a hard blocker.

### 2. Per ticket, in priority order
For each ticket:
1. **`/implement {id}`** — builds it on its own feature branch, fast-gating + committing each subtask, then runs `/verify` (full gate + review + smoke for new features).
2. **Merge to the integration branch — local git, per the Merge policy** (no PR): if the merge is fast-forward and the full gate is known-green on this exact HEAD from this session (e.g. `/verify` just ran) → `git merge --ff-only`, no re-run. Otherwise — or after a `/resume`, when the last-green sha isn't known — resolve conflicts if any, re-run the full gate (`ci.sh full`), then merge. The merge commit carries `[skip ci]` unless `ci-on-claude: yes`.
3. Tick the ticket off in the `## Ship` state.

No CI waits, no PR round-trips — nothing to idle on, so tickets flow one after another. (Use `/pr` instead of the local merge only if the user asked for PRs / the repo requires them.)

If a ticket hits a genuine blocker: unsupervised → write `## Blocked` (ticket + reason) and move to the next independent ticket if any; supervised → surface it. Deferred/out-of-scope work is allowed but exceptional — capture it as a new backlog draft and remember it for the report.

### 3. Release
On the integration branch: `/release {bump_type}` — bump version + changelog (main session), then the `runner` executes the full gate + `scripts/release.sh` (build/publish/deploy) locally; Actions release only as fallback. Do **not** re-run the manual smoke here (it's a new-feature check, already done per ticket) unless the user asked.

### 4. Report
```
Ship complete ✓  v{new_version}
Tickets: {ids implemented}
Verified: {per-ticket smoke result}
Deferred to new tickets (exceptions): {list or none}
Blocked: {list or none}
Released + deployed: {result / URL}
```
Surface **every** deferral and blocker here — that is how out-of-scope decisions stay visible.
