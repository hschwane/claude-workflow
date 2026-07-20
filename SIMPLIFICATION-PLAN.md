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
   *same* checks locally. GitHub Actions runs only on manual/human commits and releases — Claude's
   commits carry a native `[skip ci]` marker (appended by `/commit`) unless `ci-on-claude` is on
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

**Skills: 22 → ~15**
- Keep/rewrite: `project-init`, `project-onboard`, `draft` (slim), `plan` (was `refine`,
  light), `implement` (inline test-writing; invokes `/verify` at feature-done), `verify`
  (new — the "feature done" QA step: full gate + review + smoke; standalone user-invocable,
  called by `implement`/`ship`), `commit`, `pr` (lean), `release`, `ship` (orchestrator),
  `resume` (slim).
- Utilities: `unsupervised`, `consult`, `workflow-update`, `workflow-decisions` (kept — see
  settings list).
- **Remove:** 6× `route-*`, `prioritize`, `brainstorm` (→ inline ship behavior).

**Agents: 12 → 5**
- `code-explorer` (Haiku) — bulk read → digest.
- `smoke-tester` (Haiku/high) — drives the app from explicit prose test instructions
  (browser/CLI), captures a screenshot/output per step, reports **failures only**. No
  decisions — executes + reports; main session judges. Used only at feature-done for new
  features (see QA flow). *Validated:* Haiku 4.5 supports computer use and outperforms
  Sonnet 4 on computer-use evals; scripted, verifiable browser steps are exactly its sweet
  spot ([Anthropic docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool),
  [analysis](https://caylent.com/blog/claude-haiku-4-5-deep-dive-cost-capabilities-and-the-multi-agent-opportunity)).
  Env note: browser driving needs Playwright/Chromium (pre-installed in cloud sessions; local
  sessions may need `npx playwright install chromium`) — fall back to CLI/API-level smoke when
  no browser is available.
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

**Verification:** a layered QA funnel — per-subtask fast gate (`runner`), full automated tests +
review + a Haiku-driven manual smoke test at feature-done (`/verify`), re-run at PR/release with a
no-change skip. Every smoke-found bug becomes an automated test. Full design in "QA / Verify Flow".

**Retired concepts:** tiers/routing, per-ticket flows (4-tier triage), 3-reviewer gate,
mandatory TDD isolation agent, prioritize/brainstorm as skills.

**Kept for autonomy:** checkpoints, recovery heartbeat, `/consult`, blocker handling.

## Estimated impact

| | Small ticket | Hard/large ticket |
|---|---|---|
| Wall-clock | −50…−70% | −30…−50% |
| Tokens/$ | −60…−75% | −35…−55% |
| Quality | ~flat (evidence replaces ceremony) | slight risk on very large diffs → mitigated by conditional reviewer + `/verify` + `/consult` |
| Simplicity | 22→15 skills, 12→5 agents, one model | same |

Drivers: no cache-invalidating model switches (~14/ticket → 0); **expensive** (session/best-tier)
spawns 5–7 → 0–1 — remaining spawns are cheap Haiku runners by design; no CI polling waits;
~half the instruction text loaded.

## Execution phases (each independently releasable)

- **P1 — Rip out routing.** Delete 6 `route-*` skills; remove `routing:` spec blocks, `tier:`
  checkpoint lines, step-down/re-arm rules from refine/implement/pr/ship/resume/unsupervised.
  Set model policy: session model + `/consult`(best/high) + Haiku agents. *Big win, low risk.*
- **P2 — Reshape agents (12 → 5).** Remove test-writer, RE, tech-planner, doc-writer,
  product-owner, workflow-coach; fold functions inline. Generalize `test-runner` → `runner`
  (entrypoint executor); **create `smoke-tester`** (Haiku/high); merge 3 reviewers → one
  `reviewer` (best/high). Update all skill references.
- **P3 — Simplify core flows + build `/verify`.** `refine`→`plan` (light, no over-scoping, no
  triage, surfaces questions, defaults to in-scope; produces observable acceptance criteria).
  `implement` (inline scoped test-writing, per-subtask fast gate via `runner`). **New `/verify`**
  (full gate + review + smoke per QA flow). `pr` (lean: no CI polling, `[skip ci]`-aware squash
  message, review by judgment — per CI Usage Concept). `/commit` appends `[skip ci]` per the
  `ci-on-claude` decision. Remove `prioritize`; de-skill `brainstorm`; slim `draft`.
- **P4 — `/ship` orchestrator.** Input-adaptive (specs | topic | both) → batch all questions
  up front → autonomous plan→implement→test→review→smoke→docs→release→report, with
  out-of-scope deferrals surfaced in the report.
- **P5 — Docs model + context trim.** Inline minimal doc-comments policy; one concise
  maintained architecture doc (updated in a light end-of-ship pass + during `implement` when
  structure changes); minimal user docs (favor self-explanatory UI + in-app hints). Trim root
  CLAUDE.md 164→~90 and **add directory-scoped CLAUDE.md files** (`src/`, `tests/`, and deeper
  where a dir has real conventions) so specialized guidance loads only when working there.
  `/workflow-decisions` kept (see settings list below).
- **P6 — Delivery.** Update project-init/onboard/workflow-update to install/reconcile the
  leaner set (remove deleted skills/agents on update). Version bump + migration note.

(`/verify` = the "feature done" QA step, designed in "QA / Verify Flow".)

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

2. **Who triggers a paid CI run — via GitHub's native `[skip ci]`:**
   - **Claude's commit** → `/commit` **appends `[skip ci]`** to the commit message (when
     `ci-on-claude` is off) → GitHub natively skips push/pull_request workflows; the run never
     starts (true zero minutes). Verified: native keywords `[skip ci]`/`[skip actions]` work for
     `push` and `pull_request` events ([GitHub docs](https://docs.github.com/actions/managing-workflow-runs/skipping-workflow-runs),
     [changelog](https://github.blog/changelog/2021-02-08-github-actions-skip-pull-request-and-push-workflows-with-skip-ci/)).
   - **Manual/human commit** (no marker) → **CI runs** — guards changes that skipped the local gate.
   - **`ci-on-claude: on`** (libraries) → `/commit` simply **doesn't append** the marker → CI runs
     on Claude's work too. The setting is a **local decision read by `/commit`** — no repo
     variable, no workflow `if:` logic needed at all. (Fallback if conditional-run-with-record is
     ever wanted: `vars` context in job `if:` is confirmed to work —
     [docs](https://docs.github.com/en/actions/reference/workflows-and-actions/variables).)
   - Detection can't use the actor — Claude pushes via the user's `GH_TOKEN`, so `github.actor`
     is identical for human and Claude. The commit message is the only reliable channel, and
     `/commit` must append the marker **itself, deterministically** (never rely on a harness
     adding trailers — local Claude Code sessions don't).

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

**Implementation caveats (nail during build):**
- **No required status checks** on repos using this scheme: a workflow skipped by `[skip ci]` or
  paths-filters leaves its checks **stuck "Pending" — a PR requiring them can never merge**
  (confirmed: [GitHub docs](https://docs.github.com/actions/managing-workflow-runs/skipping-workflow-runs)).
  Branch protection must not mark the CI job as required; the local gate is the gate.
  `project-init`/`onboard` should check & warn.
- **Release workflow is `workflow_dispatch`-ONLY when `release-runner: local`** — if it also
  triggered on tag pushes, Claude's local release (which pushes the tag) would fire it and
  **publish twice**. Tag trigger only when `release-runner: ci`. This also sidesteps any skip-
  keyword ambiguity around tag pushes.
- **Squash merges:** `/pr` must set the squash commit message explicitly (subject/body) so the
  `[skip ci]` marker is present (or absent, for `ci-on-claude: on`) on the merge commit landing
  on main — never rely on GitHub's auto-generated message.
- **Mixed pushes:** skip detection keys on the pushed HEAD commit — avoid pushing a batch where
  Claude's marked commit sits under a human commit or vice versa; in practice each party pushes
  its own work immediately, so this stays theoretical.
- **Canonical entrypoint has two modes:** `ci.sh fast` (format+lint+typecheck+affected unit
  tests — the per-subtask gate) and `ci.sh full` (everything incl. integration/e2e + build —
  feature-done/PR/release and what the CI wrapper calls). Both defined at init; parity anchor
  for local and CI alike.

**Distributed across phases:** canonical entrypoints (`ci.sh` fast/full, `release.sh`) → P6
(templates/init/onboard) + P3 (commit/implement/verify call them); `[skip ci]` handling → P3
(`/commit`) + P4 (`/pr` squash message); monitored release fallback → P3/P4; `ci-on-claude` +
`release-runner` decisions → P6 (workflow-decisions). Not a standalone phase.

## QA / Verify Flow (designed)

Layered funnel, cheap→expensive. Automated tests carry the breadth; the manual smoke test is a
*discovery* tool run once per new feature, and everything it finds gets codified into automated
tests — so the manual surface shrinks over time.

**Per subtask — fast gate (`runner`, Haiku).** format + lint + compile/typecheck + the new &
adjacent unit tests. The agent digests output so it never floods the main context. Keeps every
commit green (load-bearing for autonomous `/resume` — never build on a broken checkpoint). The
deployable build artifact + integration/e2e are NOT run here — they're deferred to feature-done.

**Feature done — full verification** (the `/verify` step; end of `/implement`, per ticket in `/ship`):
1. **`runner`:** format + lint + compile + **all automated tests** (now including integration/e2e
   + the deployable build).
2. **Review** — self-review (default) or `reviewer` agent (best/high, critical only); Claude's judgment.
3. **Manual smoke test — new features only.** Main session writes the **fewest UI/CLI-level steps
   that meaningfully validate the new feature** (each step: action + **expected observable
   result**), from the acceptance criteria — *as few as possible, as many as needed*; breadth is
   the automated tests' job, not this. Hands them to the **`smoke-tester` (Haiku/high)**, which
   drives the app on a **local/test instance** (browser/CLI, test data, step budget) and **reports
   only the steps that FAIL** — expected vs observed + a screenshot — staying silent on passes
   (keeps the report and the main context small). Main session acts on the reported failures.
   - **Never prod.** Run locally if at all possible. If the app genuinely can't run locally (needs
     cloud services/hardware), do NOT skip — agree a **project-specific strategy with the user** (a
     debug/staging deployment or preview env), decided per project and documented (`deploy.md`).
   - **Dual signal:** if the agent can't complete clear steps, that flags a likely **usability**
     problem (a novice would struggle too) — though a failure can also be an agent limitation on a
     usable app, so the per-failure screenshot lets the main session tell them apart.
   - **Regression rule:** any bug found → fix → **add an automated test** so it can't recur.
   - Criteria↔tests↔behavior: each acceptance criterion is demonstrated by a passing automated
     test *or* a smoke step; a criterion with neither is flagged.

**PR — branch done.** Re-run **all automated tests**. **Skip when HEAD is unchanged since the last
green full run** (e.g. a single-ticket branch whose feature-done run already covered this exact
commit). Many tickets on one branch (main-only model) is fine — the boundary is "branch done". No
manual smoke here.

**Release — develop+release branch model.** Re-run **all automated tests** on the release
promotion. **No manual smoke** unless the user explicitly requests it — smoke is a new-feature
check, not a release gate.

**Skip principle (no redundant runs):** the full automated suite runs at each boundary
(feature-done, PR, release) but is skipped whenever HEAD hasn't changed since the last green full
run. Cheap per-subtask fast-gate always runs.

## Parked

- Nothing — CI usage and the QA/verify flow are both designed. (`/verify` is the "feature done"
  step above; no separate parked design remains.)

## Resolved sub-questions

- **`workflow-decisions` — kept** as the skill to change workflow settings (list below).
- **Reviewer trigger — Claude's judgment** (self-review vs. `reviewer` agent), no fixed
  path/size rule; agent runs best/high, used sparingly.
- **Architecture doc — light end-of-ship pass** + updated during `implement` when structure
  changes.

## Workflow settings after simplification (~16 → ~8)

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
| **ci-on-claude** (new) | yes / no — also run GitHub CI on Claude's own commits (default off for apps, on for libraries). Implemented purely in `/commit`: off → append `[skip ci]`, on → don't. No repo variable, no workflow logic | local decision, read by `/commit` |
| **release-runner** (new) | `local` (default — Claude releases in-session) / `ci` (isolate publish secrets to Actions) | release skill / decisions |

## Suggestions from the review (proposed, not yet decided)

1. **`pr-mode: pr | direct` setting.** For solo apps on main-only, the PR itself is mostly
   ceremony: review is local, CI is skipped, merge is squash-now. A `direct` mode (commit to
   main, no PR) would cut a whole class of `gh` API calls and waits — aligned with "rely on
   GitHub less". Default `pr` (libraries/collab; keeps history + PR record); `direct` opt-in
   per project at init. Costs: no PR-level record/rollback point; slightly weaker audit trail.
2. **Smoke-instructions as a saved artifact.** Store the feature's smoke steps in the spec file
   (checked off by the smoke-tester run). Costs nothing, gives a re-runnable manual-test record
   for later regressions and for the user to run by hand if they want.
3. **`gh` budget rule.** One place (CLAUDE.md) states: batch `gh` reads, never poll, prefer
   local git for anything git can answer — makes the "less GitHub" goal an explicit rule the
   model follows everywhere rather than an emergent property.
