# QA / CI / environments overhaul — working plan

Status: **DECIDED** (user has ruled) · **OPEN** (needs a decision) · **PARKED**
Target: **3.1.0**, on top of the other unreleased changes. See "Delivery process" near the end.

> **No settings migrations needed — there are no existing 3.x projects.**
> This applies to every settings change in this overhaul: removing `deploy` (D) and adding
> `review-depth` (G) are plain template edits. No `/workflow-update` step has to delete a stale
> `deploy:` line or back-fill a new row, because the only projects that will ever run a 3.x → 3.y
> update are ones created *after* these changes land. The v2 → v3 path writes the settings block
> fresh from the template, so it inherits the new shape for free — the v2 mapping rows for a
> removed setting are simple deletions.
> Keep this in mind when writing the tickets: it removes a whole class of work that the equivalent
> change would need later, once projects exist in the wild.

---

## A. CI — settled, only three concrete fixes

**CI is a backup for humans, never a dependency.** It exists for the case where a human coded
without running the gate locally. A GitHub Actions outage or budget cap must never be able to block
a release — that has already happened once.

The `[skip ci]` marker is keyed on the **head commit** of the push or PR, so *the last committer
decides*: Claude committed last → marker → no CI, because the local gate just ran. Human committed
last → no marker → CI runs. "Never run CI after we checked locally" is therefore enforced by the
mechanism, not by a rule anyone has to remember. **No trigger changes needed.**

| Case | Fires | Correct |
|---|---|---|
| Human codes, opens PR → main/develop | `pull_request` → `ci.sh full`, **before** the merge | ✓ |
| Human merges locally, pushes trunk | `push` on `{{CI_BRANCHES}}` — after the merge, unavoidably | ✓ backstop |
| Claude opens a PR / merges | nothing | ✓ |
| Claude cannot gate locally | `workflow_dispatch` (already present) | ✓ |
| `release-runner: ci` | `release.yml` dispatch (already present) | ✓ |

Settled: workflow always installed, always kept current when the gate/release/deploy changes.
No setting. `release-runner` stays. Tag pinning stays.

### A1. Fixes — **DECIDED**

1. **`release-github.yml` has no dependency-install step.** Its siblings run `npm ci` /
   `uv sync --locked`; this one has a bare `# Add language toolchain setup here…` comment and goes
   straight to `bash scripts/release.sh`, which calls `ci.sh full`, which drives every stage
   through the package manager. On a bare `ubuntu-latest` it cannot succeed for any project with
   dependencies. Fix: scaffolder fills it from `CI_LANGUAGE_TEMPLATE`, or the template carries the
   same step its siblings do.
2. **`permissions: { contents: read }`** on all four CI workflows. The release workflows already
   scope theirs; the CI ones inherit the repo default (read/write on older repos).
3. **`pull_request:` has no branch filter** — a PR targeting a feature branch runs the full gate.
   Add `branches: {{CI_BRANCHES}}`, the same token already substituted on the push trigger.

---

## B. Gate + smoke placement per branching model — **DECIDED**

`trunk-branch` and `branching` both stay as settings.

**`main-only`** — one full gate, before the merge to the trunk. Smoke test runs on the feature
branch, before that merge.

**`git-flow`** — two full gates:
1. merging feature → `develop`
2. releasing (`develop` → trunk)

Smoke on the feature branch as above, plus an **optional second smoke between merge and release**
against the develop state — **ask the user** rather than running it by default.

---

## C. Environments — **DECIDED**

### Vocabulary (fixed — use these three words everywhere)

| Name | Exists when | Fed by | Managed how |
|---|---|---|---|
| **production** | always (if the project deploys at all) | `/release` → `release.sh` | the only target `deploy` means |
| **reference** | `branching: git-flow` | **automatically follows `develop`** — updated after every merge into develop | see C2 — mechanism matters |
| **dev** | always — Claude's own testing environment. Local by default; a deployed one **only** if local is genuinely impossible or cannot surface the bug | nothing — not branch-tracking | **Claude, manually.** Started on demand, stopped right after use. No CI, no update automation |

Most projects therefore have exactly one deployment (production) plus a local dev environment.
`git-flow` adds reference. A deployed dev environment is a last resort, not a default.

**Data and API rules for dev:**
- Real APIs are **preferred** wherever usable.
- Mock only what genuinely cannot be used in a test environment.
- If using the real API **costs money or tokens → ask the user for permission first.**

**Isolation rule for reference:** separate service/project, separate database, separate secrets,
separate domain. No shared writable resource with production, ever.

### C1. Placement — **DECIDED**

- **`app-baseline.md`** carries the model: the three environments, the isolation rules, the
  API/mocking policy. Everything in the baseline is aimed at bigger apps, and it stays a
  recommendation `/plan` can adapt or reasoned-reject.
- **`/project-init` (and `/project-onboard`) recommend** the reference environment when
  `branching: git-flow` — **with an opt-out**.
- Standing it up **lands as a tech-backbone ticket**, not scaffolder work. That milestone already
  covers "release/deploy pipeline end-to-end", so a second environment fits, and it goes through
  plan → implement → verify like anything else.

### C2. **How reference tracks `develop` — `[skip ci]` is a trap here**

Requirement: reference is updated after **every** merge into `develop`.

The obvious implementation — a GitHub Actions workflow on `push: [develop]` — **does not work**.
Claude's merge commits carry `[skip ci]`, which suppresses *every* workflow for that commit, not
just CI. So the reference environment would silently stop tracking develop the moment Claude does
the merging, which is the normal case. This is the same trap as A2, in a place where it fails
silently rather than visibly.

**DECIDED — same pattern as everywhere else: local first, CI as the fallback.**

`scripts/deploy-reference.sh` — a **dedicated script**, deliberately not a `--env` flag on a shared
deploy script, so there is no argument that can point production-ward by mistake.

After a merge into `develop`, exactly one of:

1. **Claude runs `scripts/deploy-reference.sh` locally** (the default) and the merge commit keeps
   its `[skip ci]`.
2. **Claude does not run it** → the merge commit is pushed **without** `[skip ci]`, and a
   `reference-deploy.yml` workflow on `push: [develop]` does it. Note `[skip ci]` is per *commit*,
   not per workflow, so omitting it also runs the normal CI job on that push — harmless, arguably
   a bonus.

This is only reachable under `branching: git-flow`; `main-only` has no reference environment, so
neither the script nor the workflow is installed.

**The asymmetry is the safety property, and it should be stated as a rule:**
> Read-only operations take an environment argument (`healthcheck.sh --env reference`).
> Deploying operations get **separate scripts per target** — never a flag.
> A typo in a flag deploys to the wrong environment; a typo in a script name fails to run.

Proposed structural guard, matching the stated fear: `deploy-reference.sh` resolves its target and
**refuses to run if that target is the production one** named in `docs/dev/deploy.md`. Cheap, and it
makes "wrong target" an error rather than an outage.

---

## D. `deploy` setting → replace with scripts — **DECIDED**

Evidence: the `deploy` value has **no runtime consumer**. `release.sh`'s `{{DEPLOY}}` is a
*separate* token filled with a literal command, so the project already edits the real thing freely.
The label's live uses are only:
- `/workflow-settings` follow-through: "offer to install the matching guideline" — **dead since
  3.1.0**, all guidelines are installed now;
- filling the header of `docs/dev/deploy.md`;
- the init-time decision to copy `railway.json`.

So it is a descriptive label costing always-loaded bytes in `CLAUDE.md` on every turn, and the user
is right that in practice it is either empty or a custom command.

**Proposal:**
- **Drop `deploy` from the settings block.** `docs/dev/deploy.md` becomes the single place that
  describes the target — it already holds the URL, secrets and rollback. `railway.json` becomes an
  init-time question, not a persisted setting.
- **Add `scripts/healthcheck.sh [version]`** as a canonical entrypoint. Clear standalone value:
  "is prod healthy right now, and is it serving the version I think?" is needed for `/release`
  step 9, for rollback decisions, and after any incident — none of which should require running a
  release. `release.sh` step 5 becomes `step scripts/healthcheck.sh "$VERSION"`. Keeps the existing
  hard rule that the check must **assert** the version, not merely reach the endpoint.
- **`scripts/deploy.sh` — recommended, not mandated.** Extract it when deploy is non-trivial or
  when redeploy/rollback needs to run standalone; leave it as an inline `step` in `release.sh` when
  it is a one-liner or a no-op (Railway/Vercel auto-deploy on push).
- **`scripts/dev.sh`** — bring up the local dev/test environment. Falls out of section C anyway,
  and solves the standing problem that smoke-test environment prep is re-derived from scratch on
  every `/verify` (see F).

`dev.sh` and `healthcheck.sh` become **first-class canonical entrypoints** alongside
`ci.sh`/`release.sh` — listed in `CONTRIBUTING.md`, tracked in `delivery.json` (class `mixed`, same
reasoning as the other two: project commands interleaved with plugin scaffolding), walked by
`/workflow-update`. The pattern's value is one known name per job.

### D1. Blast radius — surveyed, not yet touched

**Removing the setting** — every site that mentions it:

| File | What has to change |
|---|---|
| `templates/CLAUDE.md.template` | delete the `deploy: {{DEPLOY_TARGET}}` line from the settings block |
| `skills/workflow-settings/SKILL.md` | delete the table row **and** the follow-through bullet ("offer to install the matching guideline" — already dead since 3.1.0) |
| `skills/workflow-update/SKILL.md` | two sites: the v2-migration mapping row, and the "authoritative values" sentence. Both are plain deletions — see the no-migration note below |
| `skills/project-init/SKILL.md` | step 2's "just set `deploy: railway` in the `workflow-settings` block" |
| `skills/project-onboard/SKILL.md` | "Set `deploy: railway` in `workflow-settings`" |
| `agents/project-scaffolder.md` | drop `{DEPLOY}` from the "settings go in the block" list. **Keep** the `{{DEPLOY_TARGET}}` → DEPLOY mapping — that token also fills `deploy.md.template`, which stays |
| `scripts/_check_settings.py` | 8 settings → 7 |

`DEPLOY` survives as a **scaffolder handoff variable** (an init-time question), just not as a
persisted setting: it still decides whether `railway.json` is copied and what goes in
`docs/dev/deploy.md`.

**Adding the scripts:**
- `templates/scripts/healthcheck.sh` — **checks production by default**, with an optional argument
  to check another environment: `./scripts/healthcheck.sh [version] [--env reference|dev]`
  (exact flag shape TBD). House style: repo-root
  assertion, anti-suppression `probe()` that exits rather than returns, refuse-on-empty guard with
  a `HEALTH_ALLOW_EMPTY` escape. **Structural guard worth having:** when a version argument is
  given, at least one probe must compare against it — reaching an endpoint proves it answers, not
  that the new version is live. Same shape as `FULL_CHECKS`.
- `templates/scripts/dev.sh` — bring up the **dev** environment (local by default) with test data;
  `--info` prints the URL and test credentials for `smoke-tester`'s `HOW_TO_RUN`. Never production.
  **Assumption to confirm:** C says dev needs "no CI or special script", but read in context that
  is about *update automation* — dev tracks no branch. `dev.sh` is the on-demand start/stop
  mechanism, which is exactly what "started on demand, stopped right after use" needs. Proceeding
  on that reading; drop `dev.sh` if the intent was that Claude just invokes the project's own
  `npm run dev` each time.
- **`docs/dev/deploy.md` gains an environment table** — one row per environment: name, URL, which
  branch feeds it, what data it holds, which secrets. `healthcheck.sh --env` needs the URLs to come
  from somewhere, and today the template describes a single target.
- `templates/scripts/release.sh` — step 5 becomes `step scripts/healthcheck.sh "$VERSION"`, a fixed
  command rather than a `{{HEALTHCHECK}}` token. `{{DEPLOY}}` stays a token; the authoring note
  gains "extract to `scripts/deploy.sh` when it is non-trivial or needs to run standalone".
- Consumers to rewire: `/release` step 9 (deploy verification), `/verify` §4 (env prep → `dev.sh`),
  scaffolder Step B (fill + strip authoring notes, same rules as the other two scripts),
  `CONTRIBUTING.md.template`, `delivery.json`.

`scripts/check.sh` counts scripts and skills dynamically, so no hardcoded totals need touching
there — only `_check_settings.py`.

---

## E. Gate: no zero-test runs — **DECIDED, implement**

The gate refuses zero *stages* (`CHECKS=0`, `FULL_CHECKS=0`) but accepts a stage that ran zero
*tests*. Whether "no tests collected" is a pass depends entirely on the runner — vitest passes,
pytest exits 5, jest exits 1. A subtask can be committed green having executed nothing. Same hole
`CHECKS=0` exists to close, one level down.

- Per-language authoring note requiring the strict flag (`--passWithNoTests=false`; pytest exit 5
  treated as failure; verify cargo's behaviour).
- Plus a `ci.sh`-level guard analogous to `FULL_ALLOW_NONE`, so the invariant does not depend on
  each project's runner flags being right.
- Escape hatch consistent with the existing three: env var + a required `tech-debt.md` entry.

### E1. `fast` runs new + adjacent unit tests only — **DECIDED**

Today `ci.sh fast` runs the whole unit suite, while `/commit` and `runner.md` both already claim it
runs "affected" tests — prose describing behaviour the script does not have. **Fix the prose
regardless of what we decide here.**

#### Only the test runner knows what "adjacent" means

Path-based mapping (`src/foo/bar.ts` → `tests/**/bar*`) is per-project, fragile, and blind to the
module graph: a change in `src/util.ts` that breaks `foo.test.ts` is not selected, so the gate goes
green on broken code. Claude naming the files has the same blindness *and* rests on self-report,
which this workflow deliberately does not trust anywhere else. The runner's own changed-files mode
walks the real import graph, so it is the only option that delivers *adjacent* rather than
*similarly named*.

| Runner | Mode | Notes |
|---|---|---|
| vitest | `vitest related --run <files>` / `--changed` | git-based, walks the module graph |
| jest | `--onlyChanged` / `--findRelatedTests <files>` | same |
| pytest | `pytest-picked` (git-based) or `--testmon` (stateful) | **both are extra dependencies** |
| cargo | none | compilation dominates anyway; selection saves little |
| ctest | `-R <regex>` | name-based only, no graph |

#### Proposed shape

1. **Selection applies to `fast` only; `full` always runs the whole unit suite.** In `ci.sh`:
   `fast` runs `{{UNIT_TESTS_SELECTED}}`, `full` runs `{{UNIT_TESTS}}`. CI parity is preserved
   (CI calls `full`), merges and releases lose nothing, and only the per-subtask loop gets cheaper.
2. **Degrade to more, never to less.** Where the runner has no selection mode (cargo, cmake, or a
   python project we will not add a dependency to), `{{UNIT_TESTS_SELECTED}}` is filled with the
   *same command* as `{{UNIT_TESTS}}`. There is no configuration in which selection silently
   reduces the gate to nothing.
3. **Zero selected tests fails the gate** (the E guard applies here specifically). `/implement` 2b
   requires every subtask to write tests, so "nothing relates to what I just changed" is a finding,
   not a pass.
4. **Escape hatch is upward:** when in doubt, run `full`. `/implement` already has a rule naming
   the cases that require it; extend that list rather than inventing a new flag.

#### Gotcha to verify during implementation

A **brand-new test file is untracked**, and `git diff --name-only HEAD` does not list untracked
files. If the runner's changed-files mode is built on that, the subtask's *newly written* test —
precisely what we most want run — is not selected, and the gate passes having skipped it. Same
class as the `git diff` vs `git status --porcelain` bug already fixed in `/commit` §1b. Mitigation
is probably `git add -N` before the run, or passing new test paths explicitly. **Verify against
each runner rather than assuming.**

#### Forks — **DECIDED**

- **Default-on.** The scaffolder fills selection at init for every language whose runner can do it.
- **An extra dependency is acceptable** where it is a well-supported extension that actually solves
  the problem — so pytest gets `pytest-picked` or `pytest-testmon` rather than being left on the
  whole suite. Pick one during implementation and record why in `decisions.md`.
- **Do it now**, not deferred. The counter-argument (a slow unit suite is a test-quality smell)
  is answered by rule 1: `full` still runs everything after every ticket, so nothing is hidden —
  only the per-subtask loop gets cheaper.
- cargo/cmake still degrade per rule (2) — same command as `{{UNIT_TESTS}}`, never less.

---

## F. Criteria-verification table — mechanize existence — **DECIDED**

`/verify` §3 builds a four-column table and stores it under `## Criteria verification`. The skill
calls it "the only mechanism in the workflow that catches an implementation whose own tests agree
with it" — but nothing enforces that it was written. Contrast `last-gate.json`, which exists
*because* trusting Claude's prose about the gate was judged insufficient. The table makes a stronger
claim on weaker evidence, and a skipped §3 is byte-identical to a completed one in the report.

**DECIDED** — mechanize *existence and shape*, not honesty:
- No `status: done` / move to `completed/` without a `## Criteria verification` section.
- Row count must equal the criterion count in `## Acceptance criteria`.
- A small script both the Stop hook and `/verify` call, so it survives compaction and `/resume`.

It cannot verify the table is truthful; it removes "silently skipped" as a failure mode, exactly as
`last-gate.json` did for the gate.

---

## G. `review-depth` setting — **DECIDED**

| Value | Meaning |
|---|---|
| **`critical-only`** *(default)* | Today's behaviour: `reviewer` agent only for security-sensitive / structurally significant / high-blast-radius changes, or an external-oracle value |
| `critical+complex` | The above **plus** changes touching a lot of pre-existing code, or with many moving parts. Same logic for PRs: review if it contains a critical change **or** if complex/wide-reaching code changed |
| `always` | Every ticket and every PR gets a `reviewer` pass |

**Idempotence (DECIDED, all levels):** never review twice in a row when nothing changed between.
A `/verify` review followed by a `/pr` review on an identical diff is one review. Needs a recorded
reviewed-sha marker — same shape as `last-gate.json`'s `sha` — so it survives compaction.

Default is **`critical-only`** — today's effective behaviour, so adding the setting changes nothing
for existing projects until someone opts in. `/workflow-update` writes that value into every
project's block; the `(default)` marker in `/workflow-settings` is what it reads to know.

---

## I. One validity rule for the gate **and** the review — **DECIDED**

**Requirement:** the full gate runs after **every ticket** and **every PR** — including when several
tickets are built on the same branch — but **never twice on unchanged code**. Identical rule for
review (G's idempotence clause). Both are the same predicate over the same two facts.

> A recorded result is still valid iff: it was recorded for this mode, it passed, its `sha` equals
> `git rev-parse HEAD`, it recorded `dirty:false`, **and `git status --porcelain` is empty right
> now**. The one documented exception: it also stands when
> `git diff --name-only <recorded sha>..HEAD` touches nothing outside `docs/specs/`.

Multi-ticket-on-one-branch falls out of this for free: ticket A's completion commit is spec-only,
so the exception keeps A's result valid; ticket B's first code commit moves HEAD and invalidates it,
so B gets its own full run. Nothing special has to be written for that case — but it does have to be
*true*, which today depends on which of four phrasings a session happens to read.

### I1. The rule exists four times, in four different strengths — fix that

| Site | Current wording | Problem |
|---|---|---|
| `/verify` §1 | the full 5-condition rule + the docs/specs exception | the good one — this is the reference |
| `CLAUDE.md` Merge policy | "the full gate already passed on this exact HEAD" | drops the dirty/porcelain conditions |
| `/ship` step 2 | "known-green on this exact HEAD **from this session**" | "from this session" does not survive a compaction; the artifact does |
| `/pr` §1 | "re-run the gate **if the merge changed code**" | a judgment call, not a comparison — and merging the base into the branch is exactly when it changes |

Make `/verify` §1's rule the single definition and have the other three reference it. Better still,
put the comparison in a script (`scripts/gate-status.sh` or a helper the skills call) so it is
executed rather than recited — the same reasoning that produced `last-gate.json` in the first place.

### I2. Review gets the same artifact

`.claude/memory/last-review.json`, same shape as `last-gate.json` (`sha`, `dirty`, plus the depth it
ran at). Without it, "do not review twice if nothing changed" relies on session memory, which is
precisely what compaction destroys. With it, `/verify` and `/pr` can both ask the same question and
get the same answer.

## J. `main-only` + branch-watch = continuous deployment — make it a real mode

**The defect.** Under `main-only` with a platform watching the trunk, the merge ships. `release.sh`
step 1 ("Gate — never release on a red suite") then runs *after* production is already serving, and
the healthcheck asserts `$VERSION` while production is running new code under the **old** version
number — the bump commit's own push is a second deploy that finally makes the assertion true.
`/pr` becomes the release; `/release` becomes bookkeeping. git-flow does not have this problem
because its trunk only receives code at release time, so "trunk changed" and "we released" are the
same event by construction.

**Decision: do not ban it — CD is the point for small projects. Make it coherent.**

### J1. The rules that make merge-is-release safe

1. **Version bump + changelog happen BEFORE the merge, on the feature branch.** This is the
   keystone. Production must never run unlabelled code, and every downstream check
   (`healthcheck.sh <version>`, rollback, "what is live?") depends on the deployed artifact
   carrying the right version from its first second.
2. **The merge must be `--ff-only`.** Then the trunk's tree is bit-identical to the tree that
   passed `/verify`. If it cannot fast-forward: rebase and re-gate. Never a merge commit into a CD
   trunk without re-verifying — the merged result is a tree nothing has ever tested.
3. **The recorded gate must be valid on the exact commit being merged** (section I's five-condition
   rule). This *is* the release gate; it just runs earlier. Nothing about the gate weakens — it
   moves.
4. **Smoke on the feature branch is load-bearing, not optional.** Section B already puts it there
   for `main-only`; under CD it is the last human-shaped check before users see the change.
5. **Tag the merge commit.** Under ff that is the same tree that was verified.
6. **`healthcheck.sh $VERSION` after the deploy settles.** Unhealthy → roll back.
7. **Rollback must be real and tested**, not a prose paragraph — it is the only safety net once
   merge means ship. A `scripts/rollback.sh` (or a platform redeploy of the previous tag),
   documented in `deploy.md`, exercised once at init as part of the tech-backbone milestone.
8. **CD mode is for deployed apps only.** If `RELEASE_TYPE` is a package registry (npm/pypi),
   merge-is-release is not offered: publishing from a pre-merge branch would put an artifact on a
   registry that the trunk does not yet contain.

### J2. Batching works — the unit is the branch, not the ticket

*(Corrects an earlier draft of this section that claimed one release per ticket.)*

Several tickets can share one feature branch. Everything on that branch is verified, documented and
version-bumped together, and the merge releases the lot. So `main-only` + CD batches perfectly well;
the unit of release is simply **whatever lands on the trunk in one merge**, not the ticket.

Implication for `/ship` under this mode: use **one branch for the whole ship run** rather than a
branch per ticket, then release once at the end. `/implement`'s per-spec branching needs an "already
on the run's branch → stay on it" path.

### J3. CD is not only platform branch-watch

Deploy-on-merge generalises to **custom deployment steps** — `docker build`, `npm publish`,
`railway up` — run immediately after the merge. Both variants fit one skill; only the deploy step
differs:

| Variant | After the merge |
|---|---|
| Platform branch-watch | the platform is *already* deploying; tag, then wait and healthcheck |
| Custom steps | tag, run the deploy/publish commands, then healthcheck |

The custom variant is actually the *easier* one — the deploy is explicit and ordered, so nothing is
racing the push. Branch-watch is the case where sequencing is out of our hands, which is exactly why
rule J1.1 (bump before the merge) is the keystone.

### J4. `/pr` **is** the merge skill — `/release` delegates to it

*(Supersedes an earlier draft that gave the merge to `/release`. That draft rested on "`/pr` is
optional", which is exactly the thing being changed.)*

**Every merge goes through `/pr`.** It owns the process and all the gates. A local fast-forward is
not a *different path* — it is `/pr` choosing the cheap execution because the conditions allow it.
Local merging was a simplification for small projects, never a lower standard.

| Condition | Execution |
|---|---|
| The ticket lives on GitHub (issue linked / project uses GitHub tickets) | **Real PR.** Claude documents the gate results and any fixes in it. If a gate could not run locally, run it via GitHub Actions and record that. Merge once ready |
| No GitHub ticket **and** every gate ran green locally | **Local fast-forward merge** — faster and simpler, same gates |

Quality never differs between the two; only where the evidence is written down and who can read it.

**The unification — each skill has ONE fixed target, not a parameter:**

| | target | pre-merge | post-merge |
|---|---|---|---|
| **`/pr`** | **always `develop`** | verify still valid, review per `review-depth` | deploy **reference** |
| **`/release`** | **always the trunk** | same **+ bump, changelog, README** | tag, deploy production, healthcheck, rollback |

Both share one merge procedure (the PR-or-local decision, the gate/review validity check, the
`[skip ci]` handling); they differ only in target, pre-merge extras and post-merge actions. This
finally gives the merge an owner, which section I1 showed it never had — the rule lived as prose in
three files at three different strengths.

**Under `main-only` there is no `develop`, so `/pr` has no target.** It stops and tells the session
to use `/release` instead: on a single-branch repo, landing on the trunk *is* releasing. One
redirect rule replaces a mode flag, and CD's "bump before the merge" falls out for free because
`/release`'s prep runs before the merge it performs.

**This makes the branching choice mean something crisp:**
> `main-only` — every landing on the trunk is a release.
> `git-flow` — landing and releasing are separate events.

**Trade-off (not a blocker):** a `main-only` library that publishes to npm/pypi can no longer merge
several branches and release later — each landing publishes. The answers are batch on one branch,
or use `git-flow`.

**This must be written into the project, not just this plan — but only where it applies.**
Condition: `branching: main-only` **and** `RELEASE_TYPE` is a package registry (npm/pypi), i.e. the
projects where landing on the trunk publishes something irreversible. In those, the scaffolder
writes a short paragraph into the release section of `docs/dev/deploy.md` saying: every merge to the
trunk publishes, so batch tickets on one branch when you want one release, and switch to `git-flow`
if landing and releasing need to be separate events. Everywhere else the note is noise and is not
written — a project with `deploy: none` and no registry has nothing to warn about, and an
unconditional warning teaches the reader to skip warnings.

Consequences elsewhere: QS matrix row 6 becomes `/pr`'s unconditional post-action. `/ship` calls
`/pr` per ticket then `/release` once under git-flow, and `/release` per branch under `main-only`.
`/release` still needs the PR-or-local decision itself, since a `main-only` project with GitHub
tickets should still get a real PR.

## K. The QS matrix — one row per event

The quality process stated once as a table rather than scattered across six skills. Each row names
what runs, what artifact proves it ran, and what may skip it.

| # | Event | Checks | Artifact | Skippable? |
|---|---|---|---|---|
| 1 | **Ticket ready** (`/plan`) | observable acceptance criteria; provenance for any value whose answer exists outside the code (two mutually-constraining anchors where an authority exists); subtasks; test scope; no open `[USER]` | spec `status: ready` | never |
| 2 | **Every edit** | `protect-files` (pre), `auto-format` (post) | — | hooks, always on |
| 3 | **Subtask done** | `ci.sh fast` — format, lint, types, **new + adjacent unit tests** (E1), zero-test guard (E); commit only on green | `last-gate.json` (`fast`) | never |
| 4 | **Ticket done** (`/verify`) | `ci.sh full`; review per `review-depth`; **criteria table**; smoke | `last-gate.json` (`full`), `last-review.json`, `## Criteria verification`, smoke record | table never; smoke only when no user-visible surface; gate/review only per the I-rule |
| 5 | **Merge → `develop`** (`/pr`) *(git-flow only)* | gate + review still valid for this exact commit (I); docs current; PR-or-local decision | merge commit / PR | never |
| 6 | **Post-merge to `develop`** (`/pr`) *(git-flow only)* | `deploy-reference.sh`, then `healthcheck.sh --env reference` | — | never |
| 7 | **Release — merge → trunk** (`/release`) | everything in 5, **plus** version bump, changelog, README check; gate valid on the commit being merged | tag | never |
| 8 | **Post-release** (`/release`) | deploy production; `healthcheck.sh $VERSION`; **rollback if unhealthy** | healthcheck result | never, where the project deploys |

Rows 5–6 exist only under `git-flow`; under `main-only` `/pr` redirects to `/release`, so a feature
branch goes 4 → 7 → 8. Rows 1–4 and 7–8 are the same in both models.

### Row 8 — post-release verification — **DECIDED**

*(Correcting an earlier claim in this plan: row 8 is not ownerless. `/release` step 9 owns it today
— it is just thin: one paragraph, no wait, no defined rollback, and duplicated by `release.sh`
step 5.)*

| | |
|---|---|
| **Wait** | poll until the deploy settles, with a timeout. Under branch-watch the push returns immediately while the platform builds for minutes — a check fired straight after the push probes the *old* version |
| **Verify** | `healthcheck.sh $VERSION` against **production**, asserting the version, not merely liveness |
| **Recover** | unhealthy → **fix it**. Rollback is the fallback, not the reflex: a failed release is a problem to solve, not to revert away from. Roll back to protect users, then diagnose and fix forward |
| **Artifact** | **none, deliberately** — see below |

**Which healthcheck is authoritative:** the post-merge one. `release.sh`'s internal healthcheck step
runs before the platform has finished under CD, so it cannot be the check that counts.

**Each merge skill checks its own environment:** `/pr` → `healthcheck.sh --env reference` (row 6),
`/release` → `healthcheck.sh $VERSION` against production (row 8). Same script, different target.

**Why no artifact here, when every other row has one:** liveness is not a historical fact, it is a
current one. Re-running `healthcheck.sh` and seeing the expected version answers "is the release
live and working?" better than any record of "the release steps were executed" — the record can be
true while the server is down. A re-runnable check beats a stored claim wherever the thing being
checked is still observable. (Rows 3–7 record artifacts precisely because *those* facts are not
re-observable later: which tests ran against which sha cannot be recovered after the fact.)

---

## K1. Per-row decisions

### Row 1 — "ready" is defined twice and enforced nowhere

Findings:
- `/plan` §5: *goal, observable acceptance criteria, an approach, subtasks, no open questions* — **5 items**.
- `/implement` §0: *clear goal, observable acceptance criteria, subtasks listed, no open `[USER]`* — **4 items; drops "approach"**.
- Nothing mechanical checks either. Same multi-site drift as sections I1 and J4.

**DECIDED:**

1. **Delete both restatements — do not single-source them.** The enumeration is redundant with the
   spec template, which already *is* the definition: a ready spec is one whose template sections are
   filled with no open questions, and `/plan` only sets `status: ready` and moves it to
   `docs/specs/ready/` when that holds. `/implement` can check the directory and the status instead
   of re-listing the parts. Net effect: one definition, in the template, and two paragraphs of
   always-re-read prose removed from the context.

2. **Add `## Documentation impact` to the spec template — one to two lines, no checklist.**
   The existing policy stands unchanged: *update only what the change actually affects*. Tokens
   spent on documentation nobody reads are wasted twice — writing it and re-reading it. So the
   section answers only: are docs affected at all, and if so which; **or** is there a new algorithm,
   interface, file format, contract, or other important concept that has to be written down. "None"
   is a complete and common answer. Its value is that it is decided at planning time, when scope is
   still negotiable, and that row 4 then has something concrete to check against.

3. **A review pass on the spec at the end of `/plan`.** Structured self-check against the template.
   Escalate to `advisor`/`reviewer` on the same trigger as `review-depth` — critical or complex
   tickets only, not every spec. It is the one place a bad criterion is still free to fix; after
   this, everything downstream trusts it.

The spec template currently has: Goal · Acceptance Criteria · Approach & Interfaces · Subtasks ·
Smoke steps · Open Questions. It gains **Documentation impact** (1–2 lines), and per section F
**Criteria verification** is written into it at row 4.

### Row 2 — no change

Hooks stay short, automatic and unconscious. Nothing to add.

### Row 3 — add a hands-on developer check

**DECIDED.** After the fast gate, the **main session** exercises the new behaviour directly, the way
a developer would: curl the endpoint, run the CLI command, load the page and click the thing. Not a
subagent, not blackbox, not scripted, no formal artifact — just "did I actually run this?".

Distinct from the smoke test, and both are needed:

| | who | sees | derived from | when |
|---|---|---|---|---|
| **hands-on check** (row 3) | main session | everything — code, spec | whatever it just wrote | per subtask |
| **smoke test** (row 4) | `smoke-tester` agent | only the steps | the acceptance criteria | per ticket |

The hands-on check catches "it doesn't even run" before the ticket is declared done; the smoke test
catches "it runs but does not do what was asked". Neither substitutes for the other.

### Row 4 — structured smoke scope, plus a docs check

**DECIDED.** Replaces `/verify` §4's current "write the fewest steps that meaningfully validate":

- **1–3 scenarios for the main story**, as described and intended in the ticket.
- **One step per acceptance criterion.**
- **Additional steps allowed** for complex interactions *between* criteria, or for other areas of
  the project this change could plausibly affect.
- **Verify the documentation was actually updated**, against the spec's new `## Documentation
  impact` section — which is what makes this checkable rather than a reminder.

### Rows 5 and 7 — the gate is all-or-nothing, the review is incremental

**DECIDED, identical rule for both merges:**

- Skip **both** the full suite and the review when only one ticket was built on this branch **and**
  nothing changed between ticket-done and the merge (section I's validity rule).
- If anything changed: **re-run `ci.sh full` in full** — a partial test run proves nothing — but
  **scope the review to the diff since the last review**, using `last-review.json`'s sha as the base.

This asymmetry is the point: tests are cheap to repeat and meaningless when partial; review is
expensive to repeat and perfectly meaningful when scoped to a delta.

**Row 7 additionally:** in **long unsupervised runs**, a second smoke pass here covering the new
features *and* important older ones (regression). See K2.

### Row 6 — reference may not exist

**Careful.** The condition is not merely `git-flow` — section C makes the reference environment a
*recommendation with opt-out*. Row 6 runs only when `branching: git-flow` **and** a reference
environment actually exists. Where it does not, the row is absent, not failed.

## K2. Manual-testing intensity scales with risk and autonomy

**DECIDED — a rule, not a setting.** More hands-on and smoke testing when the change is larger, more
complex or more critical, **and** the more autonomously the work is running. Less when a human is
watching a small change happen.

| Situation | Manual/smoke testing |
|---|---|
| Long unsupervised run, many tickets | **Most.** Full row-4 scope per ticket, plus the row-7 regression smoke over new *and* important older features |
| Large, complex or critical change | Full row-4 scope; extra steps for interactions and plausibly affected areas |
| Ordinary supervised ticket | Row-4 scope as written |
| Small bugfix with the user watching | Minimal — often none before the release; **none at all if it is trivial** |

Rationale worth keeping in the text: automation removes the human who would otherwise have noticed
something odd in passing. The less supervision a run has, the more the workflow has to buy that
attention back deliberately. This is the same judgment axis as `review-depth`'s `critical+complex`,
applied to manual testing — so the two should read as one idea, not two unrelated heuristics.

### J5. Both J-opens, resolved by J4

*(This subsection was numbered J3 twice; renumbered. Both questions are now answered.)*

**1. How is the CD mode determined? — there is no mode.** J4 removed the need: under `main-only`,
`/pr` redirects to `/release`, so landing on the trunk is always a release. J1's rules
(bump-before-merge, `--ff-only`, tag, healthcheck) are harmless where nothing auto-deploys and
necessary where something does, so no flag has to distinguish the two. `branching` alone decides.

**2. Is `release.sh` still the entrypoint? — yes, with its gate made conditional.**
`/verify release` now runs the gate, so `release.sh`'s unconditional `ci.sh full` would violate the
I-rule by running it twice on unchanged code. But `release.sh` is *also* the CI fallback path, where
no `/verify` ran and the gate is the only one there is.

Resolution: **`scripts/gate-status.sh`** — exits 0 when the recorded full-gate result is valid for
HEAD (the five-condition comparison), non-zero otherwise. `release.sh` runs `ci.sh full` only when
it exits non-zero. In CI there is no `last-gate.json`, so it exits non-zero and the gate runs, as it
must. This makes the I-rule an **executable** with exactly one implementation, called by `/verify`
(all modes) and by `release.sh`.

`release.sh` therefore keeps: conditional gate → build artifact → publish → migrations → deploy.
Healthcheck leaves it entirely (row 8 owns it, post-merge, after the deploy settles).

## H2. `/verify` itself — **target shape DECIDED; read-through stays post-implementation**

`/verify` is the largest skill (12 KB) and the most load-bearing, and the overhaul touches four of
its five steps. Two separable questions: *what shape should it end up in* (needed **now**, so the
tickets are written against a target) and *is the result still coherent as one document* (only
answerable **after**, by reading it whole).

### `/verify` becomes THE verification skill, with a mode parameter

**`/verify ticket|pr|release`.** All verification logic lives here; `/pr` and `/release` call it
rather than restating checks. The skeleton is identical in all three cases — the depth and scope
change, not the kind of checking. Default mode is `ticket`, so `/verify FEAT-001` keeps working
(a first argument that looks like a ticket id means `ticket`).

| | `ticket` (row 4) | `pr` (row 5) | `release` (row 7) |
|---|---|---|---|
| full gate | per the I-rule | per the I-rule; skipped when one ticket and nothing changed since ticket-done | as `pr` |
| review | per `review-depth`, whole diff | per `review-depth`, **scoped to the delta since `last-review.json`** | as `pr` |
| criteria table | **mandatory** | — already done per ticket | — |
| smoke | row-4 scope (K1) | none | regression pass in long unsupervised runs (K2) |
| docs check | vs `## Documentation impact` | — | — |

### The separation this creates

`/verify` **checks it is safe to act**; `/pr` and `/release` **act**. What is left in them is only
their own mechanics:
- `/pr` — the PR-or-local decision, writing gate results into the PR, the merge itself, the
  post-merge reference deploy.
- `/release` — bump/changelog/README prep, tag, production deploy, healthcheck, rollback.

The five-condition comparison stays a **script**, but now only `/verify` calls it — mechanical
enough that it must not drift back into prose judgement, while the *decision* about a failed
comparison stays beside it in the skill.

### What moves out of `/verify` regardless

| Today, prose | Becomes |
|---|---|
| §2's escalation judgement | the **`review-depth` setting** (G) + `last-review.json` |
| §3's "store the table" instruction | **a script** checking section presence and row count (F) |
| §4's environment prep | **`dev.sh`** (C/H3) |
| §4's "how many steps" | the row-4 scope rule (K1) + K2's intensity scale |

Plus one addition: the **documentation check** against `## Documentation impact`.

### Expected outcome — corrected

An earlier draft predicted `/verify` would end up under 12 KB. With the mode parameter it absorbs
rows 5 and 7, so **it may well grow** — the honest metric is the **sum of `/verify` + `/pr` +
`/release`**, which must shrink, because the gate-and-review logic stops being written three times
at three different strengths. If that sum grows, something was described twice rather than moved.

### Still post-implementation

The read-through itself. Once the pieces land: does it read as one document, is anything now said
twice across `/verify`, `/pr` and `/release`, and did the shared predicate actually get shared
rather than copied.

## H. Smoke testing — **DECIDED**

Answered elsewhere, no longer open:
- **environment** → C + `dev.sh` (started on demand, stopped right after use);
- **how many steps** → K1 row 4: 1–3 for the main story, one per criterion, extras for interactions
  and plausibly affected areas;
- **when it is worth running** → K2's intensity scale (autonomy × risk);
- **does it belong in `/pr`** → no. Row 5 has no smoke; the regression pass lives at row 7 in long
  unsupervised runs.

### H1. `smoke-tester.md` contradicts itself — **DECIDED**

Two sections cannot both hold as written:
- *"Output — failures only. Report **only** steps where observed ≠ expected. Stay silent on passes."*
- *"A pass needs evidence too … for **every** step, record what you actually observed — the literal
  text on screen, the response body, the exit code."*

If the output is failures-only, the evidence for a passing step has nowhere to go — so a pass and a
skipped step stay indistinguishable, which is the exact thing the second section was added to
prevent.

**DECIDED — one compact evidence line per step, full detail for failures only:** a table of
`step · pass/fail · one-line literal observation`, then the existing detailed block (expected /
observed / screenshot / could-not-complete) for failures alone. The caller does not wade through
prose, and "all steps passed" stays checkable.

**And the corollary, which is on the caller, not the agent:** every step must state its inputs and
its expected output literally. **The smoke-tester makes no judgement calls** — it does not decide
whether something "counts as" passing, whether a near-match is close enough, or whether a difference
matters. Observed ≠ expected is a failure, reported as such; the main session decides what it means.
A step vague enough to need interpretation is a defect in the step, and the agent should report it
as could-not-complete rather than resolve it.

### H4. No smoke artifact — **DECIDED: correct, by the row-8 rule**

Smoke needs no stored artifact, for the same reason row 8 does not: the **steps live in the spec**
and are re-runnable, which beats a record that they once ran. Nor is there a double-run risk —
row 4 is per ticket, row 7 per run, different scopes by construction, so idempotence has nothing to
prevent here.

### H3. `dev.sh` → `HOW_TO_RUN` — **DECIDED**

`dev.sh --info` prints the URL and test credentials; the main session passes that verbatim as the
agent's `HOW_TO_RUN`, starts the instance before handing off and stops it right after (per C). This
is what removes the standing cost of re-deriving environment setup on every `/verify`.

---

## L. `docs/dev/` — what belongs there, and how anyone knows what is there

Two gaps, both small, both real.

### L1. Nothing tells `/plan` what a dev doc is *for*

The templates ship four files — `architecture.md`, `code-style.md`, `setup.md`, `deploy.md` — and
`CLAUDE.md` states the principle ("what would be expensive to re-derive from the code"). Nothing
turns that into a decision anyone makes. So `docs/dev/` only ever contains the four scaffolded
files, and the things most expensive to re-derive are exactly the things never written down.

**Beyond the four pre-created files, a ticket should add a dev doc when it introduces:**
- a **complex algorithm**, or one that forms the **base of the software** — the kind whose *why*
  and whose invariants are unrecoverable from the implementation;
- a **file format**;
- an **API interface**;
- a **network protocol**;
- any other **contract** — something a second implementation would have to match exactly;
- similar designs that are **hard to enumerate comprehensively later**, or hard to understand from
  the code alone.

The test is not "is this complicated" but **"would someone have to reconstruct this by reading the
whole implementation?"** If yes, it belongs in `docs/dev/`. Note this is deliberately narrower than
"document the code" — the documentation policy (minimal, only what the change affects) still holds,
and the `## Documentation impact` line in the spec (K1) is where the call gets made, at planning
time, while scope is still negotiable.

### L2. There is no index, so skills and agents cannot know what exists

`/plan` deciding doc impact, `code-explorer` orienting, `reviewer` and `advisor` receiving context —
all need to know what `docs/dev/` holds without reading every file to find out. Today the only way
is to list the directory and open things.

**Proposed: `docs/dev/README.md` — one row per document, one line each.** Same pattern as the
guidelines `INDEX.md` (trigger → file), which already proves out: skills read the index, not the
bodies, and open a body only when it matters. Cheap to maintain (one line when a doc is added),
and it is what makes L1's new documents *findable* rather than merely written.

Wiring: `/plan` reads it when filling `## Documentation impact`; `/implement` updates it when adding
a doc; `code-explorer` already orients via project docs and gains a real entry point.

---

## Delivery process (user-defined)

These changes ship **on top of the other unreleased changes**, as **3.1.0**.

1. **Review and update the plan** ← current phase
2. **Update the workflow** according to the plan
3. **Review** the changed workflow and fix what it finds
4. **Compaction pass** — save tokens and context; make everything more comprehensive *and* more
   concise (note the sum-of-three-skills metric in H2 is one concrete measure for this phase)
5. **Final review**, including a round of real live checks similar to the 3.0 rounds
6. **Release as 3.1.0** once it is genuinely releasable

---

## Implementation order

Bottom-up: mechanisms first, then the skills that call them, then the installers that deliver them.

**1 — Scripts and templates (no skill depends on them yet)**
1. A1: `release-github.yml` install step; `permissions: contents: read` ×4. *(A1.3 shipped in `b211360`.)*
2. `scripts/gate-status.sh` — the five-condition predicate as an executable (I, J5).
3. `ci.sh`: zero-test guard (E) + `{{UNIT_TESTS_SELECTED}}` for `fast` (E1).
4. `healthcheck.sh` (`[version] [--env]`), `dev.sh` (`--info`), `deploy-reference.sh`;
   `release.sh` gate becomes conditional on `gate-status.sh`, healthcheck step leaves it (D, C2, J5).
5. Spec template: `## Documentation impact` (K1 row 1).
6. `criteria-check` script — section presence + row count (F).

**2 — Settings**
7. Drop `deploy` (D1); add `review-depth` (G). Template block, `/workflow-settings`,
   `_check_settings.py`, and every site D1 lists.

**3 — Skills**
8. `/plan` — delete the ready enumeration, add `Documentation impact` + the L1 dev-doc trigger,
   add the end-of-plan spec review.
9. `/implement` — readiness by directory+status, hands-on developer check (K1 row 3), `fast`
   selection wording.
10. `/verify` — the mode parameter and everything that moves in or out (H2).
11. `/pr` — the merge skill: target `develop`, PR-or-local, redirect under `main-only`,
    post-merge reference deploy.
12. `/release` — prep → `/verify release` → `/pr` → tag → deploy → row 8.
13. `/ship` — one branch per run under `main-only`; call sites.
14. `smoke-tester.md` — per-step evidence line, no judgement calls (H1).

**4 — Guidelines and docs**
15. `app-baseline.md` — the three environments, isolation, API/mocking policy (C).
16. `docs/dev/README.md` template + the L1 rules; `docs/dev/deploy.md` environment table (D) and
    the conditional CD note (J4).

**5 — Installers**
17. `project-scaffolder`, `/project-init`, `/project-onboard` — new scripts, the reference-env
    question, `docs/dev/README.md`, deploy-setting removal.
18. `/workflow-update` — new files, removed setting, new variants.
19. `delivery.json` — entries for every new file.

**6 — Self-check**
20. `_check_consistency.py` cases for every cross-file claim above; `_check_gate.py` cases for the
    zero-test guard and `gate-status.sh`.
