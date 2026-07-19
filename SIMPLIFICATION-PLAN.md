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
3. **Review.** Inline self-review by default. Escalate to `/consult` when needed, or spawn
   **one independent reviewer agent for the most critical tickets only**. No 3-reviewer gate.
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
- `reviewer` (one, conditional, best/high) — most-critical tickets only; merges the old
  code+security+architect concerns into one pass.
- **Remove:** `test-writer`, `requirements-engineer`, `tech-planner`, `documentation-writer`,
  `product-owner`, `workflow-coach`. Their functions move inline (session model).

**Verification:** local quality gate (`/commit`) + `/verify` that actually **runs the change**
(CLI/endpoint/browser) and reports observed behavior. This is what makes cutting reviews/CI safe.

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
- **P4 — `/verify`.** New skill: run scoped tests locally + exercise the feature
  (CLI/curl/browser) + report observed behavior. Wire into `implement` and `ship`.
- **P5 — `/ship` orchestrator.** Input-adaptive (specs | topic | both) → batch all questions
  up front → autonomous plan→implement→test→review→docs→verify→release→report, with
  out-of-scope deferrals surfaced in the report.
- **P6 — Docs model + context trim.** Inline minimal doc-comments policy; one concise
  architecture doc; minimal user docs. Trim CLAUDE.md 164→~90; slim templates; drop
  workflow-decisions if empty.
- **P7 — Delivery.** Update project-init/onboard/workflow-update to install/reconcile the
  leaner set (remove deleted skills/agents on update). Version bump + migration note.

## Parked (separate design later)

- **CI concept.** Design how CI is actually used (when to gate, when non-blocking, how to
  stop breaching Actions free-tier, how to avoid long agent waits). Interim during P3:
  local tests are the gate; still push + let CI run as a non-blocking backstop; stop the
  hard poll-and-wait on `gh pr checks`; minimize `gh` calls.

## Open sub-questions to settle as we implement

- `workflow-decisions`: remove entirely, or keep a tiny version for a few real toggles
  (e.g. "block on CI: yes/no", "critical-review: on/off")?
- "Most critical ticket" trigger for the reviewer agent: by label, by touched paths
  (auth/crypto/payments/data-migration), by size, or explicit `/ship` flag?
- Where the maintained architecture doc lives and who updates it (implement step vs. a
  lightweight end-of-ship pass).
