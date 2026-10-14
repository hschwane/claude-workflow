# claude-workflow v4 — plan

Status: **planning.** Nothing here is implemented. Decisions marked **[open]** need the user.

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
**[open] plugin name** — skills are invoked as `/<plugin>:<skill>`; `claude-workflow` is long,
something like `wf` reads better.

### Skills

| Skill | Invocation | Job |
|---|---|---|
| `setup` | user only | New project: interview, decide, scaffold minimal (§5) |
| `onboard` | user only | Existing project: interview, decide, fit the gate to its real commands; **also migrates v3 projects** (§7) **[open: or a separate `migrate`]** |
| `guidelines` | model + user | One reference skill: trigger table in `SKILL.md`, each guideline a supporting file read on demand (§6) |
| `spec` | user (model may suggest) | Design docs, specs from ideas or from a design doc, enrichment of terse input into a gauntlet-grade bar (§8) |
| `deliver` | user only | One or more specs/changes, each through build → gate → fresh critic → fix, capped (§9) |
| `gauntlet` | user only | A whole goal/epic from a prompt or design doc, decomposed, built and judged against the original (§10) **[open: or one skill with `deliver`]** |
| `release` | user only | Version, changelog, tag, deploy, assert the live version |

### Agents
- **`critic`** (best model, read-only + screenshots): judges an artifact against a bar with fresh
  context — binary verdict plus confidence, findings with *what* and *why*, restricted to
  correctness, the bar and stated requirements. Replaces `reviewer`, the smoke-tester's UI mode
  and `advisor`. Everything else is dropped (`/run`, `/verify`, Explore cover the rest).

### Hooks
- **Stop gate, active only while a `deliver`/`gauntlet` run is open** (a state file the skill
  writes and clears): blocks the turn from ending until `scripts/ci.sh fast` passes. Outside a run
  nothing is enforced — principle 1. **[open] always on instead?**

### Workflows (plugin `workflows/`)
- `gauntlet.js` — the epic loop (§10), taking `args` `{ goal, bar, sources, cap }`.
- `deliver-batch.js` — several specs in parallel isolated copies, each with its own critic.

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
  conversation/goal only). Stored in the settings block; `spec`, `deliver` and the mod read it.
- **Tests:** levels and runner; **CI:** yes/no; **docs:** what goes in `docs/dev/` (§2 rule);
  **git:** branching (`main-only`/`git-flow`) and trunk; **release:** type, runner, deploy target,
  health check; **UI:** none / test UI / style guide later.
- Scaffold from data, not prose: `ci.sh` filled from `stages.json` (init) or from the project's
  real commands (onboard), a CLAUDE.md under ~80 lines, the CI workflow when `github: yes`.
- If the project is a runnable app: run `/run-skill-generator` once so `/run`/`/verify`/`critic`
  can start it.
- Verify before finishing: `ci.sh full` green with ≥1 test, the counts reported.

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

## 7. Migrating v3 projects

`onboard` detects a v3 project (`.claude/workflow-source.json`, `.claude/guidelines/INDEX.md`, the
`workflow-settings` block) and switches to migration. The frozen v3 `delivery.json` ships inside
the skill as the source of truth for what the plugin owned.

1. **Report first, change nothing:** every v3 path with its fate — remove / keep / convert — and
   why. The user confirms.
2. On a branch:
   - **Remove** plugin-owned copies (`plugin` class): `.claude/skills/`, `.claude/agents/`,
     `.claude/hooks/` and their `settings.json` entries, `.claude/guidelines/`,
     `workflow-source.json`, templates, `claude-loop.sh`.
   - **Keep** project-owned work: `scripts/ci.sh`, `release.sh`, `healthcheck.sh` (already filled),
     `docs/specs/` (spec mode `files`), `docs/design/`, `docs/dev/` documents the project wrote.
   - **Convert:** the `workflow-settings` block → the v4 settings block; `.claude/memory/decisions.md`
     → `docs/dev/decisions.md` (only real decisions) or CLAUDE.md lines; `gotchas.md` → CLAUDE.md
     gotchas if short; `tech-debt.md` → issues (if `github: yes`) or `docs/dev/tech-debt.md`;
     CLAUDE.md → strip the v3 workflow prose, keep project blocks, cut to the §2 rule; `dev.sh` →
     `/run-skill-generator` recipe, then removed.
   - **Install** the plugin at project scope (`enabledPlugins` / marketplace in `.claude/settings.json`).
3. **Prove it:** `ci.sh full` green before and after with the same test count; the report lists
   every removed and converted file.
4. Tested first on one real v3 project of the user's, before the release.

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
1. Build the bar (§8 enrichment if needed); open a run (state file → Stop gate active).
2. Claude implements freely — no prescribed steps.
3. Gate: `ci.sh fast` via the Stop hook; `ci.sh full` before the critic.
4. `critic` with fresh context judges against the **spec and its sources** (design doc, style
   guide, reference); UI work is judged on screenshots from `/run`.
5. Fix and re-judge, **at most 4 rounds**; what remains goes to the user. Close the run, set status
   `done`, commit (and merge per the branching setting).

Several specs: sequential in-session, or `deliver-batch.js` in parallel isolated copies.

## 10. `gauntlet` — a whole goal, from a session or a Projects coordinator

Input: a goal plus the bar — a prompt, a design doc, a reference to beat. Specs are optional
intermediate artifacts; **the critic always judges against the original**, which is the point:
deriving specs first would only ever check against the specs.

1. Enrich into a bar (named, fetchable, comparable); show it; the user confirms once.
2. Decompose into sub-tasks, each carrying the slice of the original it serves.
3. Per sub-task: builder → gate → critic (fresh; sees bar + artifact, never the builder's history)
   → loop, capped.
4. Final critic on the **whole result vs the whole original bar**; failing parts re-enter step 3.
5. Report: what was built, each verdict with its evidence, what is still open.

Two runtimes, one skill:
- **Normal session:** the plugin's `gauntlet.js` workflow (agents as builders/critics, resumable,
  no mid-run questions — the bar is confirmed before it starts).
- **Projects coordinator:** the coordinator is the lead; threads are builders on their own
  branches; critics run as separate threads or subagents against the original bar; merges via PRs.
  **Unverified whether a coordinator can run plugin skills/workflows** — spike in §12 P0.

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
| **P0 spikes** | (1) plugin skill named like a bundled one (`verify`) — which wins; (2) Projects: do threads/coordinator get project plugins, can a coordinator run a plugin skill or workflow; (3) a plugin workflow with `args` and a judge loop; (4) a mod pane in the cloud app submitting a plugin command; (5) Stop hook gated by a state file | each answered with evidence; plan adjusted |
| **P1 skeleton** | new layout + `marketplace.json`; `guidelines` skill; `setup`/`onboard` (no migration yet); CLAUDE.md + settings templates | `setup` on an empty TS app and a Python lib; gate green with counts |
| **P2 deliver** | `spec`, `deliver`, `critic`, Stop gate | live run: 3 specs incl. one UI spec with seeded defects (the v3.3 fixture) |
| **P3 gauntlet** | `gauntlet` + `gauntlet.js`; coordinator variant if P0 allows | live run on a small epic from a design doc |
| **P4 migration** | v3 → v4 in `onboard` | one real v3 project migrated, gate count unchanged |
| **P5 mod** | `spec-board` | pane lists, selects and starts a run; tests pass |
| **P6 release** | slim `check.sh`, README, v4.0.0 | all of the above green |

Testing stays the three-level model from v3's CLAUDE.md, scaled down: the language matrix, a small
consistency check, a live run per skill.

## 13. Open decisions

1. Plugin name / namespace (`claude-workflow` vs something short).
2. `deliver` and `gauntlet` as two skills, or one skill choosing by input size.
3. Migration inside `onboard`, or a separate `migrate` skill.
4. Stop gate only during runs (proposed) or always.
5. Default spec mode for new projects.
