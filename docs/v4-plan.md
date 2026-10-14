# claude-workflow v4 — plan

Status: **implemented on the feature branch, release-ready, not released.** P0 was skipped by
decision. Tested end to end in real headless sessions with the plugin loaded: setup (Python CLI),
onboard (library with its own CI), convert (a v2.15 and a v3.3 project — same gate and test count
before and after), deliver (3 UI specs with seeded defects, real `wf:critic`), gauntlet (an epic
from a design doc; the mod's `wf_usage` tool was called), release (publish failure path). Every
finding from those runs is fixed and asserted in `scripts/_check_consistency.py`.
Not exercised: the spec-board pane on screen and `$.command.run` from it; a Projects coordinator.

## 1. Why

v3 is ~51,000 words of skills and agents (`project-scaffolder` 10k, `workflow-update` 8k,
`project-init` 6k, `project-onboard` 5k, `verify` 3k), copied into every project, with its own
test system for the prose. Most of it now duplicates Claude Code itself, and the rest is prose
telling the model how to do things current models already do. Usage check (GitHub API, Oct 2026):
0 stars, 0 forks, 0 page views in 14 days — the user is effectively the only user.

Decided with the user: **option B — a slim marketplace plugin**, keeping only what models do not
do on their own; the per-ticket workflow is **not** enforced by default.

## 2. What the research says (sources in the session notes, Oct 2026)

**Official Anthropic guidance** (code.claude.com best-practices, features-overview, memory, skills, goal, workflows):
- The single biggest lever is **a check Claude can run** (tests, build, screenshot). Escalating
  strength: in the prompt → `/goal` (a separate small model judges after every turn) → a Stop hook
  (deterministic) → a fresh-context verification subagent or workflow.
- Explore → plan → implement, but "if you could describe the diff in one sentence, skip the plan."
- **CLAUDE.md under 200 lines**; per line ask "would removing this cause Claude to make mistakes?";
  exclude anything Claude can derive from the code, standard conventions, file-by-file
  descriptions, long explanations. Procedures belong in skills, guardrails in hooks.
- Larger features: Claude interviews you, writes a self-contained spec (files, interfaces,
  out-of-scope, an end-to-end verification step), then a **fresh session** implements it.
- Adversarial review by a fresh subagent — with the warning that a reviewer asked to find gaps
  always finds some; restrict it to correctness and stated requirements.
- **Auto memory** already records user preferences, corrections and project facts, and
  deliberately **skips what can be derived from the code (architecture, file paths)**. It is
  machine-local; **Projects** add a shared memory across cloud threads.
- Bundled now: `/verify`, `/run`, `/run-skill-generator` (records a project's launch recipe as a
  project skill), `/code-review` (forked subagent), `/batch`, `/loop`, `/goal`, `/doctor
  prompt-audit`, `/skill-doctor`, `/deep-research`; dynamic **workflows** (scripted multi-agent
  runs, resumable, savable, shippable in a plugin's `workflows/`, `args` input).

**Community / evidence:**
- ETH study (arXiv 2602.11988): developer-written context files give a marginal, non-significant
  gain; generated ones a marginal loss; **all raise cost >20%**. A factorial study (arXiv
  2605.10039, 1,650 sessions) found **no** effect of file length/position/splitting on adherence;
  the strongest effect was **session length** (adherence drops as a session generates more).
- HN (incl. a self-identified Claude Code engineer): dedicated plan mode no longer needed for
  current models; elaborate review personas add little over "review this, ordered by severity";
  what still matters is human understanding, explicit handoffs, precise intent, context hygiene
  and hard guardrails.
- Frameworks (Superpowers, GSD, Spec-Kit, BMAD): consensus that they help on large features and are
  overkill on small ones; opinions, not measurements.
- Gauntlet loop (Shumer; robonuggets/jovd83/Trans4m-Tech skills): builder + **separate critic with
  fresh context** comparing the real output **blind against a named, fetchable reference bar**,
  binary pick (scores drift up), loop until it wins. Main failure: a vague bar → the critic invents
  a comparison and approves everything. This is the same lesson as v3's "independent oracle".

**How much project documentation should Claude keep for itself?** No official volume rule; the
consistent picture:
- **Always-loaded (hot):** one CLAUDE.md, well under 200 lines — commands Claude cannot guess, the
  gate, conventions that differ from defaults, gotchas that are not self-evident, pointers.
- **On demand (cold):** docs only for what someone would otherwise have to reconstruct from the
  whole implementation — a non-obvious architecture, a protocol, a file format, an algorithm,
  a significant decision (ADR-style, not routine choices). This matches v3's `docs/dev/` test and
  should stay the rule.
- **Not at all:** file-by-file maps, restated conventions, per-directory CLAUDE.md boilerplate,
  memory templates (auto memory / project memory do this), process prose.
- Specs and design docs are working artifacts, kept only where the project's spec mode says so.

## 3. Principles for v4

1. **Default: let Claude work.** No workflow prose in CLAUDE.md. Process is opt-in through skills.
2. **Enforce with machinery, not words.** Gates are scripts + hooks; judges are fresh-context agents.
3. **The bar is the original intent.** Every critic judges against the source — the prompt, the
   design doc, the style guide, the reference — not only against something derived from it.
4. **Use the platform.** Anything Claude Code ships (`/verify`, `/run`, `/goal`, workflows, auto
   memory, Projects, marketplace updates) is used, not rebuilt.
5. **Small enough to maintain.** Target ≤ 8,000 words of skill prose in total.

## 4. Target shape

Installed through the marketplace (namespaced, updated by `/plugin`), never copied into projects.
Plugin name **`wf`** — skills run as `/wf:<skill>`.

### Skills

| Skill | Invocation | Job |
|---|---|---|
| `setup` | user only | New project: interview, decide, scaffold minimal (§5) |
| `onboard` | user only | Existing project that never used the plugin: interview, decide, fit the gate to its real commands |
| `convert` | user only | A project carrying **any** older plugin version (v1.0–v3.3): remove every old plugin footprint, carry the project's decisions over (§7) |
| `guidelines` | model + user | One reference skill: trigger table in `SKILL.md`, each guideline a supporting file read on demand (§6) |
| `spec` | user (model may suggest) | Design docs, specs from ideas or from a design doc, enrichment of terse input into a gauntlet-grade bar (§8) |
| `deliver` | user only | One or more specs/changes, each through build → gate → fresh critic → fix, capped (§9) |
| `gauntlet` | user only | A whole goal/epic: rounds of specs delivered through `deliver`, every critic holding the original bar, until the result meets it (§10) |
| `release` | user only | Version, changelog, tag, deploy, assert the live version |

### Agents
- **`critic`** (`model: inherit`, read-only + screenshots): judges an artifact against a bar with fresh
  context — binary verdict plus confidence, findings with *what* and *why*, restricted to
  correctness, the bar and stated requirements. Replaces `reviewer`, the smoke-tester's UI mode
  and `advisor`. Everything else is dropped (`/run`, `/verify`, Explore cover the rest).
- **No model or effort prescriptions.** Subagents inherit the session's model unless the call
  passes one, and Claude can pass `model`/`effort` per invocation; the docs give no rule for how it
  chooses, and v3's fixed Haiku/Sonnet/best split is exactly the kind of prescription this version
  drops. Whoever wants a fixed subagent model sets `CLAUDE_CODE_SUBAGENT_MODEL`.

### Hooks
- **None by default.** A Stop hook would only stop Claude from ending a turn while the gate is red.
  Current models run the gate when the skill says so, and the `critic` refuses a pass without the
  gate's output as evidence — that covers the case. CI still guards human pushes. A hook is added
  only if the live runs show Claude stopping on a red gate.

### Workflows (plugin `workflows/`)
- None by default. Parallel runs are the exception (§9) and use bundled `/batch` or Projects
  threads; a plugin workflow is added only if P0 shows the in-session loop cannot hold.

### Mod
- **`spec-board`** pane (§11).

### Kept as is
- `languages/<lang>/stages.json` + fixtures + `check.sh --languages` — the only check that
  executes what we prescribe.
- `templates/scripts/ci.sh` (+ `gate-status.sh` simplified), `release.sh`, `healthcheck.sh`;
  GitHub CI/release templates.
- Guideline content (moved under the `guidelines` skill), including `ui-frontend` / `ux-basics`
  and the per-project style guide concept at `docs/design/style-guide.md`.

### Dropped, and what replaces it

| v3 | Replaced by |
|---|---|
| copying into `.claude/`, `delivery.json`, `/workflow-update` | marketplace install + `/plugin` updates |
| `/workflow-settings` | a short settings block in CLAUDE.md, written by `setup`/`onboard`, edited by hand |
| `/unsupervised`, `/auto-resume`, `claude-loop.sh` | `/goal`, auto mode, usage-limit auto-continue, Routines |
| `/consult`, `advisor` | subagents with a model choice; `critic` |
| `/resume` | native `--continue`/`--resume`, git, Projects memory |
| `/draft`, `/plan`, `/implement`, `/verify`, `/commit`, `/pr`, `/ship` | `spec`, `deliver`, `gauntlet`; bundled `/verify` `/run` `/code-review`; Projects coordinator |
| `smoke-tester`, `dev.sh` | bundled `/run` + `/run-skill-generator`, `critic` with screenshots |
| `runner`, `text-scout`, `code-explorer`, `project-scaffolder` | Explore agent; `setup` does its own scaffolding |
| `.claude/memory/` templates, `src/CLAUDE.md`, `tests/CLAUDE.md` | auto memory / Projects memory; one CLAUDE.md |
| most of `_check_consistency.py` | a handful of cross-file checks for the facts that remain |

## 5. `setup` and `onboard`

Both interview the user and **decide only what fits the project** (a script needs no release
process; a library no deploy):
- **Spec mode:** `files` (`docs/specs/`), `issues` (GitHub), or `none` (specs live in the
  conversation/run only). **Default `none`, always asked.** Stored in the settings block; `spec`,
  `deliver` and the mod read it.
- **Tests:** levels and runner; **CI:** yes/no; **docs:** what goes in `docs/dev/` (§2 rule);
  **git:** branching (`main-only`/`git-flow`) and trunk; **release:** type, runner, deploy target,
  health check; **UI:** none / test UI / style guide later.
- Scaffold from data, not prose: `ci.sh` filled from `stages.json` (init) or from the project's
  real commands (onboard), a CLAUDE.md under ~80 lines, the CI workflow when `github: yes`.
- If the project is a runnable app: run `/run-skill-generator` once so `/run`/`/verify`/`critic`
  can start it.
- Verify before finishing: `ci.sh full` green with ≥1 test, the counts reported.

### 5a. Where the project's decisions live

General know-how is dropped from always-loaded context: current models know how to write tests,
structure code and handle empty states, and Anthropic's own exclusion list says so ("standard
conventions Claude already knows", "self-evident practices"). **The project's choices are not
know-how** — no model can guess that this project tests only at unit level, ships a style guide,
releases to PyPI from CI, or keeps specs as issues. Those survive, in the cheapest home that works:

| Kind | Example | v4 home |
|---|---|---|
| A choice encoded in a command | test runner, lint, build | `scripts/ci.sh` — no prose needed |
| A short project decision | testing scope, spec mode, branching, release type, UI state | settings block in CLAUDE.md (~10–15 lines) |
| A deviation from defaults | "real APIs over mocks", "no ORM", "money in integer cents" | one CLAUDE.md line each, or a path-scoped rule when it only concerns some files |
| A decision the user wants kept | "never use an ORM here" | a CLAUDE.md line, **only when the user asks**; no standing decisions file — v3's `decisions.md` collected noise. Corrections and preferences are what auto memory / Projects memory record anyway |
| Operations | environments, secrets, rollback | `docs/dev/deploy.md` |
| UI decisions | design variables, components, copy, devices | `docs/design/style-guide.md` — no skill; the `ui-frontend` guideline says: an app with a UI gets its UI designed with the user, then a style guide. A model keeps one session consistent, but not your taste across sessions and threads — that is what the file is for |
| The user's own engineering opinions that differ from model defaults | independent oracle for criteria, quality over coverage, UX basics | the `guidelines` skill — on demand |
| Generic standards a model already follows | AAA, naming, small functions | dropped |

v3's `code-style.md` is split along exactly this line: the few rules that differ from defaults go
to the `guidelines` skill (or the project's CLAUDE.md when project-specific), the rest is dropped.

## 6. `guidelines` — found automatically, one skill

- One model-invocable skill whose description names the moments it applies: *designing a new
  feature or component, choosing an approach or library, building UI, a background job, logging,
  deployment, an AI integration, a bot, a map or chart.* Body: the trigger table; each guideline
  is a supporting file loaded only when its row matches. One description in context, not thirteen.
- Description matching can miss, so two deterministic touchpoints call it explicitly: `spec`
  (always, before writing a design doc or spec) and the bar-building step of `deliver`/`gauntlet`.
- CLAUDE.md gets one line: *before designing a feature, check the `guidelines` skill.*
- A project's deviation from a guideline is a line in CLAUDE.md (or `docs/dev/decisions.md` when
  it needs explanation) — no separate memory system.

## 7. `convert` — projects on any older plugin version

Named apart from `onboard` so nobody confuses it with the old onboard skill. It must handle every
release since v1.0.0 (~95 tags), not only v3: a project last updated at v1.20 has a different
footprint (`docs/workflow/`, `.claude/workflow-guidelines/`, other skills) than one on v3.3.

**The skill holds a procedure, not a table.** Claude tailors it to the project:
1. **Detect the version:** `.claude/workflow-source.json` or the settings block where present;
   for older projects, compare the project's plugin-shaped files against candidate release tags
   until one matches.
2. **Read that release** from the plugin repository (`git show v<x>:<path>`, the tag's skills,
   templates and, from v3 on, its `delivery.json`) to learn what that version put where.
3. **Classify each footprint file:** identical to the release's version → untouched plugin copy,
   safe to remove; different → edited by the project, shown with its diff, never deleted silently.
4. **Report first, change nothing:** every file with its fate — remove / keep / convert — and why.
   The user confirms.
5. On a branch: remove the untouched copies (skills, agents, hooks and their `settings.json`
   entries, guideline copies, templates, loop scripts, `docs/workflow/`); keep project work
   (filled `ci.sh`/`release.sh`/`healthcheck.sh`, `docs/specs/`, `docs/design/`, project-written
   `docs/dev/` documents); carry the project's real decisions into their v4 homes (§5a) and cut
   CLAUDE.md to the §2 rule; replace `dev.sh` by a `/run-skill-generator` recipe; install `wf` at
   project scope.
6. **Prove it:** `ci.sh full` green before and after with the same test count; the report lists
   every removed and converted file.
7. Tested on a v2 and a v3 project before release.

## 8. `spec`

Modes, chosen from the input:
- **Design doc** for something big: interview → `docs/design/<topic>.md` (goal, users, flows,
  constraints, non-goals, acceptance at the level of the whole, open questions). Consults
  `guidelines` and, for UI, the style guide / the diverge-then-converge mockup step.
- **Specs** from an idea or from a design doc: self-contained (files, interfaces, out of scope,
  acceptance criteria with an **independent oracle**, an end-to-end verification step, a UI section
  referencing the style guide), each linking back to its design doc.
- **Enrichment:** a terse line ("dark mode for the settings page") becomes a gauntlet-grade bar:
  named reference(s), fetchable checks, constraints, what must not change, the stop condition.
  This is also the first step inside `deliver` and `gauntlet`, so terse prompts are improved
  wherever they enter.
- Storage follows the spec mode: files / issue / none (the enriched bar is then shown and used
  directly). Status lives in frontmatter or issue labels: `draft → ready → in-progress → done`.

## 9. `deliver` — per spec, opt-in

Input: spec ids, an issue, or a free prompt (enriched first). Per item:
1. Build the bar (§8 enrichment if needed).
2. Claude implements freely — no prescribed steps.
3. Gate: `ci.sh full` before the critic, its output kept as evidence.
4. `critic` with fresh context judges against the **spec and its sources** (design doc, style
   guide, reference); UI work is judged on screenshots from `/run`.
5. Fix and re-judge, **at most 4 rounds**. Findings still open after the fourth are reported with
   two options: **turn them into new specs**, or **authorize another round**. Then set status
   `done` (or leave it `in-progress` while the user decides), commit, merge per the branching
   setting.
6. The gate is run by Claude as part of the work; the critic treats a missing or red gate output as
   a failed verdict.

**Several specs — sequential and grouped by default, parallel only when independent:**
- **Related specs run one after another in the same context**, so later ones build on what the
  earlier ones established and nothing conflicts. Specs that touch the same code are **delivered
  as a batch**: implemented together, gated once, but **judged per spec**, so each criterion still
  gets its own verdict.
- **Independent specs** (different areas, no shared files) may run in parallel — through bundled
  `/batch` or Projects threads, not a plugin workflow.
- Long sequences: adherence drops as a session grows (§2), so after a group the run compacts or
  hands off to a fresh session; spec status is the handoff, nothing else needs carrying.

## 10. `gauntlet` — rounds of specs against the original bar

Input: a goal plus the bar — a prompt, a design doc, a reference to beat.

**Every critic holds the original.** Each per-spec critic gets the top-level bar (the idea, the
design doc, the reference) **in addition to** what matters for its own area — its spec, the style
guide, the relevant guideline. A part is judged by how it serves the whole, not only by its spec,
so deriving specs no longer weakens the check.

**The loop runs through `spec` and `deliver`, led by a supervisor:**
1. Enrich the input into a bar (named, fetchable, comparable); show it; the user confirms once.
2. The **supervisor** compares the current state with the whole bar and writes a round of specs for
   the gaps — using the critics' feedback from the previous round as input.
3. The supervisor decides **which specs go together** (one agent or session, in sequence or as a
   batch, §9) and **which run in parallel**, then hands them to `deliver`. Every critic holds the
   original bar in addition to its spec.
4. Back to 2, until the supervisor finds the goal or vision met.

The difference from ordinary work is exactly two things: **every critic knows the overarching
version, not only its spec**, and **the supervisor keeps writing new specs** from what the critics
report until the goal is reached.

**Bounded by budget, not by rounds.** The user gives a share of the weekly subscription allowance
(e.g. "up to 15 % of this week") and a concurrency limit (e.g. "at most 3 agents at once"). The
supervisor checks the budget before each round and stops cleanly when the next round would exceed
it, reporting what is done and what is open. Source of the number: the status-line payload carries
`rate_limits.seven_day.used_percentage` (official docs); a tiny status-line script or the mod
records it at the start and after each round. Concurrency: the supervisor's own limit, backed by
`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` in a session. **Whether that payload is available in cloud
sessions and Projects coordinators is a P0 spike.**

**Why rounds of specs rather than one free-running loop in context:** each round leaves visible,
resumable state — specs with status, shown on the spec board, picked up by a fresh session or by
Projects threads. In spec mode `none` the specs exist only in the run's state, so a small goal
stays lightweight.

**Coordinator:** in a Project the coordinator is the supervisor (steps 1–4); threads deliver specs.
**Unverified whether a coordinator can run plugin skills** — spike in §12 P0.

## 11. Mod: `spec-board`

A pane listing specs by status (backlog / ready / in progress / done), live:
- `files` mode: `$.fs` lists and reads `docs/specs/**` frontmatter; `issues` mode: `gh issue list`
  through `$.process.run`; `none`: the pane says there is nothing to track.
- Select entries with toggle buttons (the mobile surface draws no `Select`/`Input`, buttons work
  everywhere); **Deliver selected** / **Gauntlet selected** queue
  `/<plugin>:deliver <ids>` or `/<plugin>:gauntlet <ids>` via `$.prompt.submit` (starts a turn
  once the session is idle).
- Optional status-line entry: the active run and its gate state.
- Verified in this build's mod API: panes, buttons, `$.fs`, `$.process.run`, `$.prompt.submit`.
  **Unverified:** whether mods load in Projects coordinator chats.

## 12. Phases

| | Work | Done when |
|---|---|---|
| **P0 spikes** | (1) plugin skill named like a bundled one (`verify`) — which wins; (2) Projects: do threads/coordinator get project plugins, can a coordinator run a plugin skill or workflow; (3) the in-session deliver loop holding over several specs with compaction; (4) a mod pane in the cloud app submitting a plugin command; (5) `rate_limits` from the status-line payload in local, cloud and coordinator sessions | each answered with evidence; plan adjusted |
| **P1 skeleton** | new layout + `marketplace.json`; `guidelines` skill; `setup`/`onboard`; CLAUDE.md + settings templates | `setup` on an empty TS app and a Python lib; gate green with counts |
| **P2 deliver** | `spec`, `deliver`, `critic` | live run: 3 specs incl. one UI spec with seeded defects (the v3.3 fixture) |
| **P3 gauntlet** | `gauntlet` on top of `spec` + `deliver`; coordinator variant if P0 allows | live run on a small epic from a design doc |
| **P4 convert** | `convert` | a v2 and a v3 project converted, gate count unchanged |
| **P5 mod** | `spec-board` | pane lists, selects and starts a run; tests pass |
| **P6 release** | slim `check.sh`, README, v4.0.0 | all of the above green |

Testing stays the three-level model from v3's CLAUDE.md, scaled down: the language matrix, a small
consistency check, a live run per skill.

## 13. Decisions

Settled with the user:
- Plugin name `wf`.
- Several specs: sequential/grouped by default, batch for specs touching the same code, parallel
  only when independent (§9).
- `gauntlet`: a supervisor writes rounds of specs (from the gaps and the critics' feedback),
  decides grouping and parallelism, hands them to `deliver`; every critic holds the original bar;
  bounded by a weekly-allowance share and a concurrency limit, not by rounds (§10).
- `deliver`: after 4 rounds, open findings are reported with "new specs" or "another round" (§9).
- `convert`: a procedure Claude tailors by reading the detected release; tested on v2 and v3 (§7).
- No standing decisions file; CLAUDE.md lines only on request (§5a).
- Style guide stays, as guideline content, no skill (§5a).
- No Stop hook by default; no model/effort prescriptions for subagents (§4).
- Spec mode default `none`, always asked in `setup`/`onboard` (§5).
