# claude-workflow — Simplification Plan (v2)

Goal: **way simpler** than today, cheaper and faster, with quality preserved by
**evidence (running the code) instead of ceremony**. Must still run autonomously
and not fail on hard tasks.

## Locked decisions (from the design conversation)

1. **Models.** One **session model** (default Sonnet) for all normal work — no
   per-ticket routing, no `route-*` skills, no tier lines. Two escapes only:
   - `/consult` → **best available model, high effort** for a hard decision (inline advisor).
   - **Haiku subagents** for high-IO / low-judgment work (bulk reading, running tests,
     mechanical scaffolding).
2. **CI — DESIGNED** (see "CI Usage Concept"). CI defines the canonical checks; Claude runs the
   *same* checks locally. GitHub Actions runs only on manual/human commits and releases — skipped
   on Claude's commits (detected by the `Claude-Session:` trailer) unless `ci-on-claude` is set
   (recommended for libraries). No non-blocking CI. Claude's normal work = 0 Actions minutes.
3. **Review.** **Claude decides per ticket**: either a **self-review** (adopting a reviewer's
   perspective in the main context) or spawn the **independent `reviewer` agent (best model,
   high effort)**. The agent is used **sparingly** — only for genuinely critical work, by
   Claude's judgment (no fixed path/size trigger). `/consult` also available. No 3-reviewer gate.
4. **Tests — keep, but quality over quantity.** Automated unit/integration/e2e are worth it
   (cheaper than Claude manually click-testing). But: scope tests to the **project and the
   ticket**, test the **important** things, drop the coverage-for-its-own-sake target.
   Writing tests = inline (judgment, session model). Running tests + all quality gates = the
   Haiku `runner` agent (runs the canonical entrypoint, digests output).
5. **`/ship` = the one input-adaptive orchestrator.** Input can be a **spec list**, a
   **topic/direction**, or both. Flow: derive/collect tickets → light refinement →
   **batch ALL clarifying questions across all tickets up front** → then fully autonomous:
   finish planning → implement with appropriate automated tests → review → edit docs →
   run verification/manual tests → release/deploy → **final report**.
6. **Out-of-scope.** Allowed to defer work to a new ticket, but it must be the **exception**
   and **called out in the final report**. Planning defaults to *including* scope; never
   silently drops something important.
7. **Documentation — minimal and useful.**
   - Code: clean and concise. Doc-comments only for function usage/params, class/file usage,
     and genuinely tricky algorithms/decisions. Not everything.
   - Technical doc: one concise, maintained architecture doc (key decisions, algorithms,
     APIs, data model). Simple, not exhaustive.
   - User doc: minimal. Prefer self-explanatory UI + in-app hints/tooltips/tutorials. Some
     markdown focused on key concepts + setup/management.

## Target architecture (much simpler)

**Skills: ~22 → ~11**
- Keep/rewrite: `project-init`, `project-onboard`, `draft` (slim), `plan` (was `refine`,
  light), `implement` (inline tests + verify), `verify` (new), `commit`, `pr` (lean),
  `release`, `ship` (orchestrator), `resume` (slim).
- Utilities: `unsupervised`, `consult`, `workflow-update`.
- **Remove:** 6× `route-*`, `prioritize`, `brainstorm` (→ inline ship behavior),
  and probably `workflow-decisions` (few settings left; fold into README).

**Agents: 12 → 4**
- `code-explorer` (Haiku) — bulk read → digest.
- `runner` (Haiku/medium) — **was `test-runner`, generalized.** Executes a **predefined project
  entrypoint** and reports pass/fail + key output lines: `scripts/ci.sh` for the quality gate
  (lint/typecheck/format/tests/build), `scripts/release.sh` for a scripted release/deploy
  (bump → build → publish/push → trigger deploy), or any other predefined project command. No
  project knowledge, never fixes/judges — pure high-IO/low-judgment, ideal for Haiku. Keeps
  verbose tooling output off the expensive main model on every run. The main session only
  decides inputs up front and takes over on failure.
- `project-scaffolder` (Haiku) — init-only mechanical file creation (slim from 252 lines).
- `reviewer` (one, **best model / high effort**) — spawned by **Claude's judgment**,
  sparingly, for genuinely critical tickets; merges the old code+security+architect
  concerns into one pass. Default path is inline self-review, no agent.
- **Remove:** `test-writer`, `requirements-engineer`, `tech-planner`, `documentation-writer`,
  `product-owner`, `workflow-coach`. Their functions move inline (session model).

**Verification:** local quality gate (`/commit`) is the immediate safety net. A dedicated
`/verify` skill (run scoped tests + a minimal real-run smoke check, report observed behavior)
is **parked pending proper design** — see "Parked". Interim: `implement`/`ship` run the scoped
test suite locally + a light smoke check inline until `/verify` is designed.

**Retired concepts:** tiers/routing, per-ticket flows (4-tier triage), 3-reviewer gate,
mandatory TDD isolation agent, prioritize/brainstorm as skills.

**Kept for autonomy:** checkpoints, recovery heartbeat, `/consult`, blocker handling.

## Estimated impact

| | Small ticket | Hard/large ticket |
|---|---|---|
| Wall-clock | −50…−70% | −30…−50% |
| Tokens/$ | −60…−75% | −35…−55% |
| Quality | ~flat (evidence replaces ceremony) | slight risk on very large diffs → mitigated by conditional reviewer + `/verify` + `/consult` |
| Simplicity | half the skills, a third of the agents, one model | same |

Drivers: no cache-invalidating model switches (~14/ticket → 0), spawns 5–7 → 0–1 for small
work, no CI polling waits, ~half the instruction text loaded.

## Execution phases (each independently releasable)

- **P1 — Rip out routing.** Delete 6 `route-*` skills; remove `routing:` spec blocks, `tier:`
  checkpoint lines, step-down/re-arm rules from refine/implement/pr/ship/resume/unsupervised.
  Set model policy: session model + `/consult`(best/high) + Haiku agents. *Big win, low risk.*
- **P2 — Prune agents.** Remove test-writer, RE, tech-planner, doc-writer, product-owner,
  workflow-coach; fold functions inline. Update all skill references. Reduce reviewers to one
  conditional `reviewer`.
- **P3 — Simplify core flows.** `refine`→`plan` (light, no over-scoping, no triage, surfaces
  questions, defaults to in-scope). `implement` (inline scoped tests, no isolation agent).
  `pr` (conditional single review, CI decoupled per Parked). Remove `prioritize`; de-skill
  `brainstorm`; slim `draft`.
- **P4 — `/ship` orchestrator.** Input-adaptive (specs | topic | both) → batch all questions
  up front → autonomous plan→implement→test→review→docs→(interim verify)→release→report, with
  out-of-scope deferrals surfaced in the report.
- **P5 — Docs model + context trim.** Inline minimal doc-comments policy; one concise
  maintained architecture doc (updated in a light end-of-ship pass + during `implement` when
  structure changes); minimal user docs (favor self-explanatory UI + in-app hints). Trim root
  CLAUDE.md 164→~90 and **add directory-scoped CLAUDE.md files** (`src/`, `tests/`, and deeper
  where a dir has real conventions) so specialized guidance loads only when working there.
  `/workflow-decisions` kept (see settings list below).
- **P6 — Delivery.** Update project-init/onboard/workflow-update to install/reconcile the
  leaner set (remove deleted skills/agents on update). Version bump + migration note.

(`/verify` is no longer a build phase — moved to Parked for proper design.)

## CI Usage Concept (designed)

**Principle:** CI is the canonical *definition* of the checks; Claude runs those same checks
locally. GitHub Actions minutes are spent only on changes Claude didn't gate (manual/human
commits) and on releases — never duplicating Claude's own local runs, unless a project opts in.
Non-blocking CI is rejected outright: a run whose result nobody consumes is pure waste (success
isn't even delivered by webhook; a post-merge failure means you already shipped). CI either
**blocks and is consumed**, or it **doesn't run**.

1. **Single source of checks (parity).** At project creation set up a canonical check
   entrypoint — a script/target (`scripts/ci.sh` / `npm run verify` / `make check`) that runs
   lint + typecheck + tests (+ build). **The CI workflow calls it AND Claude's local gate calls
   it.** Same command → no drift, no ad-hoc "looks fine", closes the self-grading gap.

2. **Who triggers a paid CI run:**
   - **Manual/human commit** (no `Claude-Session:` trailer) → **CI runs** — guards changes that
     skipped the local gate.
   - **Claude's commit** (carries the `Claude-Session:` trailer) → **CI skipped** by default —
     Claude already ran the identical canonical checks locally.
   - Detection is by the **commit-message trailer, NOT the actor** — Claude pushes via the
     user's `GH_TOKEN`, so `github.actor` is identical for human and Claude. Workflow `if:`
     skips when the head commit contains the marker, unless the opt-in variable is set.

3. **Local by default; init recommends exceptions.** Everything runs locally by default
   (`ci-on-claude: off`, `release-runner: local`). **At project creation Claude assesses the
   project and asks/recommends** an exception where it genuinely helps — e.g. `ci-on-claude: on`
   for a cross-platform **library** (matrix/multi-env local can't reproduce), or
   `release-runner: ci` to isolate publish secrets. The user confirms at creation; both stay
   toggleable later via `/workflow-decisions` (sets the repo variable / decision).

4. **Releases run locally by default; on Haiku when it's just a script.** Sequence:
   - **Main session (judgment, up front):** bump the version, prepare the changelog (summarize
     what changed). Cheap — usually a small step, bump type often a user input (`/ship minor`).
   - **Hand off to the `runner` (Haiku):** run the gate (`scripts/ci.sh`, must be green), then
     execute the release/deploy flow (`scripts/release.sh`: build → publish/push image → tag →
     trigger deploy), digesting output.
   - **On failure** (failed publish, unhealthy deploy) → control returns to the main session to
     diagnose / rollback.

   Synchronous, no Actions minutes. The same `release.sh` is the Actions fallback
   (`workflow_dispatch`) when local can't run. Both `ci.sh` and `release.sh` are run by the one
   `runner` agent — different entrypoints, same "execute + digest + report" job. **GitHub Actions release is a FALLBACK only**, used when local isn't
   possible: publish credentials aren't in the session, CI-only provenance/OIDC signing is
   required, or the build needs an environment Claude lacks. When the fallback runs it's
   monitored via subscription + one scheduled check-in + report — never sleep-polled.
   - **Deploy:** Railway apps deploy on merge (Railway watches the repo — no Actions, no
     explicit step); Claude verifies health via the Railway MCP. Other targets: Claude runs
     the deploy CLI/script locally.
   - **Setting `release-runner`** (default `local`): flip to `ci` to keep publish secrets
     isolated to Actions rather than exposing them in the session (a security tradeoff).

5. **Deployed apps:** Railway build + healthcheck is the clean-room + deploy gate; GitHub CI on
   app PRs is off by default (per #3). No Actions minutes for app development.

6. **Minutes hygiene in the templates:** `concurrency: cancel-in-progress`; `paths:` filters
   (skip docs/spec/markdown-only, mirroring the Railway watch-paths); dependency caching; cheap
   default job (lint/typecheck/unit) + heavy (matrix/e2e) only **on release** or **on-demand**
   (`ci:full` label) — never every push.

7. **Workflows kept intact & runnable.** The CI and release workflows are **thin wrappers that
   just call the canonical entrypoint** — so they can't drift from what Claude runs locally
   ("intact" for free). They run automatically on **human commits**, and every workflow includes
   **`workflow_dispatch`** so Claude can trigger it **manually as a backup** when a local run
   fails (missing tool/env). Claude keeps the wrapper in sync when the entrypoint/build changes.

**Result:** Claude's normal work = **0 Actions minutes** (local gate = CI's exact checks;
releases run in-session); manual changes stay protected by CI; libraries opt into matrix;
Actions only fires for human commits, opt-in library matrix, and release fallback.

**Implementation caveats (nail during build):** Claude's squash/merge commit to main must carry
the trailer so the main push also skips; the release workflow must be a separate tag trigger so
the skip never touches it; the canonical check script is the parity anchor — CI and local must
call the same entrypoint.

**Distributed across phases:** canonical script + `ci-on-claude` variable → P6 (templates/init)
+ P3 (commit/implement call it); no-wait PR + monitored release → P3/P4; toggle → P6
(workflow-decisions). Not a standalone phase.

## Parked (need proper design before building)

- **`/verify` skill.** Design how it exercises a change: automated scoped tests first
  (primary proof — cheaper than manual clicking), then a *minimal* real-run smoke check
  (one CLI call / endpoint hit / single UI path via the pre-installed browser), and how it
  reports observed behavior + decides what to exercise per ticket. Until then, `implement`
  and `ship` do the interim inline verification (run tests + light smoke).

## Resolved sub-questions

- **`workflow-decisions` — kept** as the skill to change workflow settings (list below).
- **Reviewer trigger — Claude's judgment** (self-review vs. `reviewer` agent), no fixed
  path/size rule; agent runs best/high, used sparingly.
- **Architecture doc — light end-of-ship pass** + updated during `implement` when structure
  changes.

## Workflow settings after simplification (~16 → ~7)

**Removed** (feature gone): refine sizing tiers, review tier rule, adaptive routing, agent
tier pins (now fixed), deferred-findings policy.

**Removed** (now fixed defaults, not tunable):
- **Session model** — just use whatever the user has enabled; not a workflow setting.
- **Consult** — always `best` model / high effort; no mapping to configure.
- **Merge strategy** — fixed: **squash + auto-merge** on a green local gate, keeping the
  ask-before-merge safety conditions (merge conflict, major/breaking version, protected
  branch requiring human approval → ask first in supervised mode).
- **Reviewer** — Claude's judgment, always available (best/high, sparing); no toggle.

**Kept (the real settings — mostly project-setup values):**
| Setting | Controls | Lives in |
|---|---|---|
| Testing scope | project default Unit / +Integration / +E2E (ticket may narrow) | quality.md |
| Branching model | main-only / git-flow | release.md |
| Version source of truth | per-language version location | release.md |
| Deploy target | railway / vercel / aws / … | deploy.md |
| GitHub integration | yes / no (skip `gh` when no) | memory/decisions.md |
| Unsupervised threshold + autonomous defaults | usage cap + autonomous behavior | settings.md / unsupervised skill |
| **ci-on-claude** (new) | yes / no — also run GitHub CI on Claude's own commits (default off for apps, on for libraries) | GitHub repo variable, read by the CI workflow |
| **release-runner** (new) | `local` (default — Claude releases in-session) / `ci` (isolate publish secrets to Actions) | release skill / decisions |
