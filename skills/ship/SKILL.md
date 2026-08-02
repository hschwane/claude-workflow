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

Be on the integration branch (`develop` if it exists, else the `trunk-branch` setting) — if on a feature branch, stop and say so.

### 1. Plan — every question, once, up front (the AFK gate)
Run `/plan` **once with every ticket** that isn't already `ready` (skip ones already in `docs/specs/ready/`). `/plan` in multi-ticket mode gathers `[USER]` questions across **all** tickets and asks them together **before any implementation starts**.

**This is the only point in the whole run where `/ship` asks the user anything.** So be thorough here: surface every decision that could otherwise interrupt implementation later — scope boundaries, ambiguous requirements, design/tech forks, anything you'd want confirmed. Ask them all now, in one chat message (a numbered list) up front so the user answers in one reply.

Once these are answered (together with the ticket-list confirmation in step 0), **the user can walk away.** From here the run is fully autonomous **regardless of supervised/unsupervised mode** — steps 2–4 never ask another question.

If `.claude/memory/local-settings.md` has `auto_resume: true` and this is a cloud session, ensure the recovery heartbeat is armed now (idempotent — see `/auto-resume`) so a limit kill anywhere in the run is recovered automatically.

Record the resolved plan (ticket order + the batched answers) in **`.claude/memory/context-ship.md`** under `## Ship` — a **fixed, branch-independent** file, because a ship run spans many feature branches. This is the only orchestration state kept (per-ticket detail lives in the specs). Update it as tickets complete; delete it (or clear `## Ship`) when the whole run is done or write `## Blocked` there on a hard blocker.

### 2. Per ticket, in priority order
For each ticket:
1. **`/implement {id}`** — builds it, fast-gating + committing each subtask, then runs `/verify` (gate + review + criteria table + smoke).
2. **Under `git-flow`: `/pr`** — it lands the branch on `develop` with the gates, choosing a real PR or a local fast-forward by its own rule, and updates the reference environment afterwards.
   **Under `main-only`: nothing here.** Landing on the trunk is releasing, so the tickets accumulate on one branch and step 3 releases them together.
3. Tick the ticket off in the `## Ship` state.

**Branching depends on the model.** Under `git-flow`, each ticket gets its own branch off `develop`, as `/implement` does by default. Under `main-only`, the whole run shares **one** branch: `/implement` stays on it for every ticket instead of branching per spec, because each merge to the trunk would otherwise be a separate release.

Nothing to idle on, so tickets flow one after another — `/pr` only waits on CI when a gate genuinely could not run locally.

**No more questions after step 1 — the user is AFK.** For any decision that comes up mid-implementation, apply a reasonable default (note the assumption in the spec/report) or `/consult` if it's genuinely hard — never stop to ask. If a ticket hits a **genuine blocker** (needs a human decision or missing credentials): write `## Blocked` (ticket + reason) to `context-ship.md`, **skip that ticket, and continue with the next independent one** — don't halt the whole run and don't ask. This holds in supervised mode too: once the up-front batch is answered, `/ship` behaves autonomously to the end. **Never defer a ticket's core work / acceptance criteria to "later" to keep moving** (see `/plan` and `/implement` scope rules) — a ticket is done only when its criteria are actually met, or it's `## Blocked`. Deferral is only for genuinely peripheral extras a ticket never required; capture those as a new backlog draft and surface them in the report.

### 3. Release
`/release {bump_type}` — from `develop` under git-flow, from the run's branch under `main-only`. It runs `/verify release`, bumps version + changelog, lands the trunk merge, tags, and executes `scripts/release.sh` locally; Actions release only as fallback.

**A long `/ship` run gets the regression smoke pass** `/verify release` describes — over the new features *and* the important older ones. Every ticket was verified alone, before the others existed, so this is the only check the combined state gets. The more tickets in the run and the less supervision it had, the more that matters; a two-ticket supervised run does not need it.

`/ship` runs to a **released version** — merging, pushing the integration branch, tagging, and the deploy `release.sh` triggers are all part of what the user asked for by invoking it (see **Merging** in `CLAUDE.md`). Don't stop after the merge to ask permission to release, and don't stop before pushing the trunk branch because a session branch rule mentions a feature branch. Stop only on a failed gate, a genuine blocker, or an action outside these steps.

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

When the run is complete (or fully `## Blocked`), clear the `## Ship` note and — if a `auto-resume: {branch}` heartbeat is armed — tear it down (delete the Routine + clear `recovery_trigger:`, per `/auto-resume`); nothing is left to recover, and the `auto_resume` setting stays on for the next run.
