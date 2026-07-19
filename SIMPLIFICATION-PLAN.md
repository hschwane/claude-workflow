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
2. **CI — PARKED.** We want a *new proper concept* for how CI is used; not designing it
   now. Interim only: local gate is primary, reduce blocking/polling pain. See "Parked".
3. **Review.** **Claude decides per ticket**: either a **self-review** (adopting a reviewer's
   perspective in the main context) or spawn the **independent `reviewer` agent (best model,
   high effort)**. The agent is used **sparingly** — only for genuinely critical work, by
   Claude's judgment (no fixed path/size trigger). `/consult` also available. No 3-reviewer gate.
4. **Tests — keep, but quality over quantity.** Automated unit/integration/e2e are worth it
   (cheaper than Claude manually click-testing). But: scope tests to the **project and the
   ticket**, test the **important** things, drop the coverage-for-its-own-sake target.
   Writing tests = inline (judgment, session model). Running tests = Haiku `test-runner`.
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
- `test-runner` (Haiku) — run suite → condensed report.
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

## Parked (need proper design before building)

- **CI concept.** Design how CI is actually used (when to gate, when non-blocking, how to
  stop breaching Actions free-tier, how to avoid long agent waits). Interim during P3:
  local tests are the gate; still push + let CI run as a non-blocking backstop; stop the
  hard poll-and-wait on `gh pr checks`; minimize `gh` calls. The `block-on-CI` setting is
  the seed this concept grows from.
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

## Workflow settings after simplification (~16 → ~11)

**Removed** (feature gone): refine sizing tiers, review tier rule, adaptive routing, agent
tier pins (now fixed), deferred-findings policy.

**Kept / simplified:**
| Setting | Controls | Lives in |
|---|---|---|
| Session model | model the session runs on (default Sonnet) | project CLAUDE.md |
| Consult / "best" mapping | what `/consult` escalates to (`best`=Fable, else Opus-compensated) | consult skill |
| Testing scope | project default Unit / +Integration / +E2E (ticket may narrow) | quality.md |
| Merge strategy & auto-merge | squash/merge/rebase, auto vs manual, ask-before-merge | pr skill |
| Branching model | main-only / git-flow | release.md |
| Version source of truth | per-language version location | release.md |
| Deploy target | railway / vercel / aws / … | deploy.md |
| GitHub integration | yes / no (skip `gh` when no) | memory/decisions.md |
| Unsupervised threshold + autonomous defaults | usage cap + autonomous behavior | settings.md / unsupervised skill |

**New:**
- **Reviewer agent** — enabled/disabled (default enabled; Claude decides when, best/high, sparing).
- **block-on-CI** — yes/no; interim knob, default likely `no` (local gate is the gate). Seed for the parked CI concept.
