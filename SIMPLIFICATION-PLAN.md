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
7. **Merging — local git, no formal PRs** (see "Merge policy"): ff-merge without re-checks when
   the gate already passed on unchanged code; otherwise resolve conflicts locally, re-run the
   gate, merge. `/pr` only on explicit request.
8. **Continuity — the repo is the checkpoint** (see "Continuity v2"): state = branch + git log +
   spec checkboxes; memory file only for Blocked + ship state; usage-guard machinery removed;
   one heartbeat per cloud unsupervised run.
9. **Documentation — minimal and useful.**
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
  called by `implement`/`ship`), `commit`, `pr` (optional utility — explicit request only, not
  in the default path), `release`, `ship` (orchestrator), `resume` (slim, repo-reconstructing).
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
- **P4 — `/ship` orchestrator + local merges.** Input-adaptive (specs | topic | both) → batch all
  questions up front → autonomous plan→implement→verify(smoke)→docs→**local merge per Merge
  policy**→release→report, with out-of-scope deferrals surfaced in the report. `/pr` demoted to
  an optional utility (explicit request only).
- **P5 — Continuity v2.** Repo-as-checkpoint: strip routine checkpoint writes from all skills
  (memory file only for Blocked + ship state); `/resume` reconstructs from branch+spec+git log;
  replace usage-guard with the **minimal 80% guard** (real usage only — statusline JSON /
  credentials file; no guard in cloud, run into the limit); simplify `unsupervised` (flag + defaults + one
  heartbeat per cloud run, armed at start / deleted at end); simplify `claude-loop.sh` (no
  marker files); session-start/stop hooks keyed on the spec.
- **P6 — Docs model + context trim.** Inline minimal doc-comments policy; one concise
  maintained architecture doc (updated in a light end-of-ship pass + during `implement` when
  structure changes); minimal user docs (favor self-explanatory UI + in-app hints). Trim root
  CLAUDE.md 164→~90 and **add directory-scoped CLAUDE.md files** (`src/`, `tests/`, and deeper
  where a dir has real conventions) so specialized guidance loads only when working there.
  `/workflow-decisions` kept (see settings list below).
- **P7 — Delivery.** Update project-init/onboard/workflow-update to install/reconcile the
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

**Distributed across phases:** canonical entrypoints (`ci.sh` fast/full, `release.sh`) → P7
(templates/init/onboard) + P3 (commit/implement/verify call them); `[skip ci]` handling → P3
(`/commit`, local merge commits) + P4 (optional `/pr` squash message); monitored release
fallback → P3/P4; `ci-on-claude` + `release-runner` decisions → P7 (workflow-decisions).
Not a standalone phase.

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
   - **Blackbox + reusable:** the smoke-tester receives ONLY the distilled step list — never the
     spec file, acceptance criteria, or implementation context. The steps are **stored in the
     spec** so they can be re-run later (regression check, or by the user manually).
   - **Never prod.** Run locally if at all possible. If the app genuinely can't run locally (needs
     cloud services/hardware), do NOT skip — agree a **project-specific strategy with the user** (a
     debug/staging deployment or preview env), decided per project and documented (`deploy.md`).
   - **Dual signal:** if the agent can't complete clear steps, that flags a likely **usability**
     problem (a novice would struggle too) — though a failure can also be an agent limitation on a
     usable app, so the per-failure screenshot lets the main session tell them apart.
   - **Regression rule:** any bug found → fix → **add an automated test** so it can't recur.
   - Criteria↔tests↔behavior: each acceptance criterion is demonstrated by a passing automated
     test *or* a smoke step; a criterion with neither is flagged.

**Merge — branch done.** Local git merge per the **Merge policy**: fast-forward + HEAD unchanged
since the last green full run → merge, **no re-run**; otherwise resolve conflicts locally, re-run
the full gate, merge. Many tickets on one branch (main-only model) is fine — the boundary is
"branch done". No manual smoke here. No PR unless explicitly requested.

**Release — develop+release branch model.** Re-run **all automated tests** on the release
promotion. **No manual smoke** unless the user explicitly requests it — smoke is a new-feature
check, not a release gate.

**Skip principle (no redundant runs):** the full automated suite runs at each boundary
(feature-done, merge, release) but is skipped whenever HEAD hasn't changed since the last green full
run. Cheap per-subtask fast-gate always runs.

## Continuity v2 — checkpoints, unsupervised & resume (designed)

**Problems today:** env-specific mechanisms that each work in only some environments (local /
cloud / docker / VS Code); constant permission prompts from trigger create/delete churn;
checkpoint writes that cost time yet are rarely needed; a usage-guard that cannot even read
usage in cloud (fails open = dead weight).

**Core principle: the repo IS the checkpoint.** Every subtask already ends in a green commit
that ticks the spec checkbox (same commit). So durable state = **branch + git log + spec
checkboxes** — identical in every environment, zero extra writes, zero extra latency.

1. **No routine checkpoint files.** The `.claude/memory/context-*` file is written ONLY for:
   - `## Blocked` (human needed — reason + what's required),
   - `/ship` orchestration state (ticket order + batched answers), updated per ticket, not per
     subtask.
   Everything else is reconstructed from the repo. (Smoke instructions live in the spec.)
2. **`/resume` = reconstruct, everywhere the same:** current branch → in-progress spec →
   compare checkboxes vs `git log` (git wins) → continue at the first unchecked subtask. No
   tier re-arm (routing gone), **no subagent-recovery ledger** (the old long-running RE/TP/
   test-writer agents are gone; the new Haiku runner/smoke agents are short-lived and
   idempotent — if one died, just re-run it).
3. **Session-start hook stays** (env-agnostic, cheap): in-progress spec on this branch →
   auto-resume in unsupervised mode, suggest `/resume` otherwise. Stop hook keys on the same
   single source of truth (unsupervised + unchecked boxes → don't stop).
4. **Usage-guard → MINIMAL 80% guard, real usage only** (replaces the ~300-line machinery: no
   `--wait/--check` modes, no wait/offer markers). One PostToolUse hook, ~40 lines:
   - **Where usage is readable → pause at 80%** (fixed default, one optional override). Two
     readable sources, in order: (1) the **statusline stdin JSON** — Claude Code ≥2.1 passes
     `rate_limits.five_hour/.seven_day` (`used_percentage`, `resets_at`) to the statusline
     command on every tick, zero API calls (official; Pro/Max) — statusline.sh caches it,
     guard reads the cache; (2) fallback: the OAuth usage endpoint via
     `~/.claude/.credentials.json` where that file exists. Covers local terminal + VS Code.
     Correct across parallel sessions (account-level numbers).
   - **Where usage is NOT readable (cloud/docker) → no guard: run into the limit.** Verified
     in a live cloud session: token FDs are not inherited by hooks/Bash children, no
     credentials file, no rate-limit data in transcripts/harness state, and the statusline is
     not invoked headless. NO deterministic-budget proxy (rejected: blind to parallel
     sessions). The kill is acceptable because the repo is the checkpoint (max loss: current
     subtask) and the cloud heartbeat resumes after the limit clears.
   - **On trip (readable envs):** finish the atomic step, commit, end the turn cleanly; resume
     when usage recovers or the user pokes. No in-session wait loops.
   - **Future slot:** if a supported cloud channel appears (e.g. `rate_limits` in hook input or
     a `claude usage --json`), plug it into the same guard — the design has the slot ready.
   Unsupervised itself stays simple: flag on → no questions, autonomous defaults, keep going,
   `## Blocked` on true blockers.
5. **Trigger churn → near zero.** The old prompts came mostly from `/pr`'s per-wake `send_later`
   check-ins — those die with the CI-wait removal (local gates, local merges). What remains:
   - **Cloud unsupervised runs only:** arm ONE recovery routine at run start, delete it at run
     end/`off`/blocked — 2 trigger operations per run total (vs. per-event). With the shipped
     server-level `permissions.allow` this should not prompt; where the host still prompts,
     it's now once per run, not constant.
   - Local / VS Code / docker: no triggers at all — recovery = session-start hook + user poke
     (or `claude-loop.sh` for fully headless terminals, simplified: no marker files, it just
     restarts and the hook resumes from the repo).
6. **One continuity story for every environment:** state in the repo (works everywhere) +
   env-appropriate wake-up (cloud: heartbeat; interactive: hook + user; headless: loop). No
   mechanism pretends to work where it can't.

## Parked

- Nothing — CI usage, QA/verify, merge policy, and continuity are all designed.

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
- **Merge strategy** — fixed: **local git merge per the Merge policy** (ff without re-checks
  when green-on-unchanged-code; else resolve + re-gate + merge). Safety asks kept in supervised
  mode (major/breaking version, protected branch). When a PR *is* explicitly used: squash +
  auto-merge.
- **Reviewer** — Claude's judgment, always available (best/high, sparing); no toggle.

**Kept (the real settings — mostly project-setup values):**
| Setting | Controls | Lives in |
|---|---|---|
| Testing scope | project default Unit / +Integration / +E2E (ticket may narrow) | quality.md |
| Branching model | main-only / git-flow | release.md |
| Version source of truth | per-language version location | release.md |
| Deploy target | railway / vercel / aws / … | deploy.md |
| GitHub integration | yes / no (skip `gh` when no) | memory/decisions.md |
| Unsupervised mode | on/off flag — no questions, autonomous defaults, keep going | settings.md / unsupervised skill |
| Pause threshold | 80% default where real usage is readable (statusline JSON / credentials file); no guard in cloud — run into the limit, heartbeat resumes | guard hook |
| **ci-on-claude** (new) | yes / no — also run GitHub CI on Claude's own commits (default off for apps, on for libraries). Implemented purely in `/commit`: off → append `[skip ci]`, on → don't. No repo variable, no workflow logic | local decision, read by `/commit` |
| **release-runner** (new) | `local` (default — Claude releases in-session) / `ci` (isolate publish secrets to Actions) | release skill / decisions |

## Review suggestions — resolved

1. **ACCEPTED, extended → local merges, no formal PRs (see "Merge policy").** Merging happens
   with plain git locally; a PR is only created when explicitly wanted (external review /
   collaboration). `/pr` becomes an optional utility, out of the default path.
2. **ACCEPTED with blackbox constraint.** Smoke instructions are stored in the spec file for
   later reuse — but the **smoke-tester never sees the spec** (blackbox: it receives only the
   distilled step list; no acceptance criteria, no implementation context).
3. **REJECTED** — no `gh` budget rule in CLAUDE.md (don't re-inflate it; the new flow barely
   touches `gh` anyway).

## Merge policy (decided)

Multiple Claude sessions may work concurrently on different branches. Merging to the
integration branch is **local git, no formal PR**:

- **Fast-forward possible AND the full gate already passed on exactly this code** (HEAD
  unchanged since the last green full run) → merge with plain git (`git merge --ff-only`),
  **skip re-running quality checks**. A ff-merge moves existing commits, so their `[skip ci]`
  markers ride along automatically — no extra CI handling.
- **Not fast-forwardable / code changed since the green run** → resolve conflicts locally,
  **re-run the full gate**, then merge. A non-ff merge commit gets the `[skip ci]` marker per
  the `ci-on-claude` decision (same rule as `/commit`).
- `/pr` remains available on explicit request (collab, external review, protected repos) —
  it is no longer part of `/ship`'s default path.

This removes PR creation/merge round-trips, most remaining `gh` API usage, and the PR-wait
machinery from the default flow entirely.
