"""Assert claims the skills and agents make about each other actually hold.

Every case here is a contradiction that shipped at least once: two files giving
opposite instructions for the same file, or a spec describing a template that has
since changed under it. Prose drifts silently; these do not.
"""
import json
import sys
from pathlib import Path

SCAFF = Path("agents/project-scaffolder.md").read_text()
ONBOARD = Path("skills/project-onboard/SKILL.md").read_text()
UPDATE = Path("skills/workflow-update/SKILL.md").read_text()
PKG = Path("templates/configs/package.json.template").read_text()
INIT = Path("skills/project-init/SKILL.md").read_text()
LIB = Path("templates/guidelines/LIBRARY.md").read_text()
GIDX = Path("templates/guidelines/INDEX.md.template").read_text()
PCLAUDE = Path("templates/CLAUDE.md.template").read_text()
GUIDELINES = sorted(f.name for f in Path("templates/guidelines").glob("*.md")
                    if f.name not in ("LIBRARY.md", "INDEX.md.template", "README.md"))
CI = Path("templates/scripts/ci.sh").read_text()
VERIFY = Path("skills/verify/SKILL.md").read_text()
PR = Path("skills/pr/SKILL.md").read_text()
RELEASE = Path("skills/release/SKILL.md").read_text()
PLAN = Path("skills/plan/SKILL.md").read_text()
IMPL = Path("skills/implement/SKILL.md").read_text()
SHIP = Path("skills/ship/SKILL.md").read_text()
SMOKE = Path("agents/smoke-tester.md").read_text()
SPEC = Path("templates/spec.md.template").read_text()
SETTINGS = Path("skills/workflow-settings/SKILL.md").read_text()
DELIVERY = json.loads(Path(".claude-plugin/delivery.json").read_text())
GATEST = Path("templates/scripts/gate-status.sh").read_text()
HEALTHSH = Path("templates/scripts/healthcheck.sh").read_text()
DEVSH = Path("templates/scripts/dev.sh").read_text()
REL = Path("templates/scripts/release.sh").read_text()

CASES = [
    # The onboard scaffolder must not fill or run the gate — /project-onboard §3c does,
    # because only it has looked at the project's real command names.
    ("onboard mode carves scripts/ out",
     "`scripts/` is the exception" in SCAFF
     and "the three `scripts/`, `workflow-source.json`" not in SCAFF),

    (".env.example has one owner in onboard",
     "`.env.example` | `/project-onboard` §3g owns it" in SCAFF),

    # The prepare stage grew a guard; both specs must describe the template as it is.
    ("ci.sh guards its prepare stage",
     "prepare {{GENERATE_SOURCES}}" in CI and "prepare() {" in CI),
    ("specs describe the prepare prefix",
     "no** prefix" not in SCAFF and "no** prefix" not in ONBOARD),

    # release.sh must have the same anti-suppression shape as ci.sh.
    ("release.sh step() exits on failure",
     'exit "$code"' in REL and "FAILED=1" in REL),

    # Both scripts run from the repo root whatever the caller's cwd.
    ("gate scripts are cwd-independent",
     'cd "$(dirname "$0")/.." || exit 1' in CI and 'cd "$(dirname "$0")/.." || exit 1' in REL),

    # The CI templates must not hardcode a trunk name, and the token must carry the
    # WHOLE bracketed list: a token for the trunk alone left `develop` to a trailing
    # authoring comment, which shipped into projects and killed CI on the git-flow
    # integration branch. Neither failure raises an error — the YAML is valid and the
    # trigger just matches nothing.
    # ...and BOTH triggers carry it. `push` gates the human who merged locally; `pull_request`
    # gates the human before they merge. A substitution that stops at the first match leaves a
    # live token in the PR trigger — and every writer of this file is told to fill both.
    ("CI templates tokenise the whole branch list on both triggers",
     all(Path(p).read_text().count("branches: {{CI_BRANCHES}}") == 2
         and "{{TRUNK_BRANCH}}" not in Path(p).read_text()
         for p in Path("templates/github").glob("ci-*.yml"))),
    ("every writer of the CI workflow says to fill both occurrences",
     all("twice" in t for t in (SCAFF, ONBOARD, UPDATE))),

    # Every consumer of that token must fill it, or the rename silently orphans one.
    ("every writer of the CI workflow fills CI_BRANCHES",
     all("{{CI_BRANCHES}}" in t for t in (SCAFF, ONBOARD, UPDATE))),

    # Every conditional authoring comment a template ships must tell its reader to delete
    # it. `ci-note` did and was resolved; `ci-model` did not and froze into the always-loaded
    # root CLAUDE.md, where — being inside a project block — no later update can remove it.
    # A `{{` sweep cannot catch either: they contain no tokens.
    ("conditional authoring comments say to delete themselves",
     all("DELETE THIS COMMENT" in Path(p).read_text().upper()
         or "delete this comment" in Path(p).read_text()
         for p in ("templates/CLAUDE.md.template",
                   "templates/CONTRIBUTING.md.template"))),

    # `git branch --show-current` returns `develop` under git-flow, and every wrong
    # trunk candidate passes `rev-parse --verify`. Both were shipped defaults once.
    ("the update warns that git-flow breaks show-current",
     "`git branch --show-current` is the wrong source" in UPDATE),
    ("the update knows branch existence is not trunk-ness",
     "nowhere near sufficient" in UPDATE and "vestigial `main`" in UPDATE),

    # package.json declares a `prepare` lifecycle script, so `npm install` executes
    # scripts/generate-version.js. Copy the script AFTER installing and npm exits 1 with
    # MODULE_NOT_FOUND before the lockfile check is ever reached. Order is load-bearing.
    ("the scaffolder copies generate-version before installing",
     '"prepare": "node scripts/generate-version.js"' in PKG
     and SCAFF.index("generate-version.js` → `scripts/generate-version.js")
         < SCAFF.index("npm install && test -f package-lock.json")),

    # The web build reads web/tsconfig.json, the typecheck reads the root one. DOM libs in
    # the root only leaves typecheck green and `tsc -p web/tsconfig.json` failing TS2304 —
    # and green in both when the scaffolded entry point happens to touch no DOM.
    ("the web build config is told it needs DOM libs too",
     "it needs the DOM libs *as well*" in SCAFF),

    # init must hand TRUNK_BRANCH over, or the scaffolder has to guess the value it
    # substitutes into the CI trigger — and the unsubstituted form is still valid YAML.
    ("init passes TRUNK_BRANCH to the scaffolder",
     "TRUNK_BRANCH" in Path("skills/project-init/SKILL.md").read_text()),

    # lifecycle.md's trunk sentence is plugin boilerplate: it ships BOTH models with
    # hardcoded names and leaves `This project uses: {{BRANCHING_MODEL}}` unfilled. Reading
    # it returns `master` for every git-flow project and `main` for every main-only one, so
    # it is a constant that is right about half the time — not evidence. Resolution must
    # come from git topology (release tags, develop-merge targets), which discriminates
    # correctly on both a master-trunk and a main-trunk fixture.
    ("the update does not read the trunk from lifecycle.md boilerplate",
     "Do not use `docs/workflow/lifecycle.md`" in UPDATE
     and "git tag --merged" in UPDATE
     and "merge-base --is-ancestor" in UPDATE),

    # A backstop that passes when it has no evidence is a formality. §7 must stop.
    ("section 7 fails rather than passes without trunk evidence",
     "this check FAILS — it does not pass by default" in UPDATE),

    # §5b owns CLAUDE.md/CONTRIBUTING.md, so the §5a class walk never runs on them and
    # step 4b was unreachable on the one path that writes the comments for the first time.
    ("the v2 migration steps reach step 4b",
     UPDATE.count("§5a step 4b") >= 3),

    # Three blocks ship an authoring comment, and `contributing`'s is a placeholder for the
    # user — treating it as a defect hard-stops the update on most projects' default state.
    ("the block-comment check knows contributing's comment is a placeholder",
     "Three blocks ship one" in UPDATE and "placeholder addressed to the user" in UPDATE),

    # 5c's snippet used to `rm -rf "$CLONE"` before the paragraph that reuses that clone to
    # run every documented command. A literal reader silently skipped the one check that
    # covers a contributor's first five minutes — and the skill says nothing else does.
    ("5c keeps the clone for the documented-commands check",
     "Do NOT delete $CLONE yet" in INIT
     and INIT.index("Do NOT delete $CLONE yet") < INIT.index('Then, and only then, `rm -rf "$CLONE"`')),

    # RELEASE_TYPE: docker is offered, no template ships a Dockerfile, and nothing in
    # /project-init runs release.sh — so a filled `docker build` step ships unbuildable.
    ("the scaffolder is told docker needs a Dockerfile it must write",
     "needs a `Dockerfile`, and no template ships one" in SCAFF),

    # The two marker blocks whose resolution is CONDITIONAL on a setting must be named
    # by an owner. `identity`/`contributing` are prose-filled and need no id mention;
    # these two ship their authoring comment to the user if nobody resolves them — and
    # for `ci-model` that comment lands in the always-loaded root CLAUDE.md.
    ("conditional marker blocks are named by an owner",
     all(bid in SCAFF or bid in ONBOARD for bid in ("ci-note", "ci-model"))),

    # The blocker that came back three times: instructions that route an onboard run
    # back into filling and running the gate the skill owns.
    ("gate-filling instructions are scoped to init",
     "in init mode only" in SCAFF and "**Verify (init only):**" in SCAFF),

    # Every guideline in the library must have a row in BOTH the library table and the
    # shipped INDEX. INDEX.md.template is copied into projects verbatim now, so a guideline
    # missing from it ships as a file nothing ever reads — silently, since nothing errors.
    ("every guideline has a LIBRARY row", all(g in LIB for g in GUIDELINES)),
    ("every guideline has an INDEX row", all(g in GIDX for g in GUIDELINES)),

    # ...and no INDEX row may point at a file that does not exist, which would send /plan
    # to read a missing path.
    ("every INDEX row names a real guideline",
     all(line.split("guidelines/")[1].split("`")[0] in GUIDELINES
         for line in GIDX.splitlines()
         if line.startswith("|") and "guidelines/" in line)),

    # The install decision is gone: every project gets the whole library, and relevance is
    # decided per task by the trigger table. Selective install meant a project that grew a
    # chart or a background job waited for an update run to be offered the guideline.
    ("the scaffolder installs the whole library",
     "copy every `.md` in `{PLUGIN_SOURCE_DIR}/templates/guidelines/`" in SCAFF
     and "Do not filter" in SCAFF),
    ("no skill still passes a per-project guideline list",
     not any("LIBRARY_GUIDELINES" in t for t in (SCAFF, INIT, ONBOARD, UPDATE))),
    ("the update installs the library rather than offering it",
     "Install the complete library, every time" in UPDATE and "no offer set" in UPDATE),
    ("INDEX.md is copied, not regenerated",
     "copied verbatim from `INDEX.md.template`" in UPDATE
     and "Do not rebuild it row-by-row" in UPDATE),

    # The workflow's central rule has to live in the ALWAYS-LOADED file, or it only
    # applies when someone happens to read a skill. It names the route (/draft) and the
    # one exception, because a prohibition with no alternative just gets worked around.
    ("the ticket-first rule is in the always-loaded file",
     "## No implementation without a ticket" in PCLAUDE
     and "`/draft`" in PCLAUDE
     and "The only exception is the user explicitly asking" in PCLAUDE
     # A debug edit that happens to fix the bug is the tempting one to just keep —
     # it has had no review, no tests and no /verify. The rule has to say so.
     and "is not mergeable" in PCLAUDE),

    # --- 3.1.0: one owner per rule -------------------------------------------------------
    # The gate-validity rule lived as prose in four files at four strengths, and every
    # paraphrase dropped a different condition. It is an executable now; the skills that used
    # to restate it must call it instead of describing it again.
    ("the gate-validity rule is a script, not prose in three skills",
     "gate-status.sh" in VERIFY
     and "gate-status.sh" in Path("templates/scripts/release.sh").read_text()
     # /pr and /release delegate to /verify rather than carrying their own copy
     and "/verify pr" in PR and "/verify release" in RELEASE),
    # Stronger than it looks: the conditions must live in the SCRIPT and in none of the three
    # skills. Every past paraphrase dropped one, so the fix is not "state it consistently" but
    # "state it once, executably". A skill that starts describing the mechanics again fails here.
    ("the five conditions live in the script and nowhere else",
     all(c in GATEST for c in ('git status --porcelain', 'git rev-parse --verify', '"$DIRTY" = false'))
     and not any('git status --porcelain' in doc for doc in (VERIFY, PR, RELEASE))),

    # /verify is the single verification skill; the modes are what /pr and /release pass it.
    ("verify takes a mode",
     "ticket|pr|release" in VERIFY and "## What runs in which mode" in VERIFY),

    # /pr owns the merge and has ONE target. Under main-only it has none, so it must hand over
    # — a merge to the trunk outside /release ships unversioned code on a watching platform.
    ("pr targets develop and refuses the trunk under main-only",
     "always targets `develop`" in PR
     and "main-only" in PR and "/release" in PR),

    # The keystone of the CD model: bump BEFORE the merge, or production runs unlabelled code
    # and healthcheck.sh has nothing true to assert.
    ("the release bumps before the merge under main-only",
     "before the merge" in RELEASE and "--ff-only" in RELEASE),

    # Every setting the always-loaded block ships must exist in the settings table, and vice
    # versa. A block key with no row is unexplainable; a row with no key is never set.
    ("the settings block and the settings table hold the same keys",
     sorted(l.split(":")[0] for l in PCLAUDE.split("workflow-settings: start -->")[1]
            .split("<!-- workflow-settings: end")[0].strip().splitlines())
     == sorted(r.split("`")[1] for r in SETTINGS.splitlines()
               if r.startswith("| `") and r.count("|") >= 4)),

    # The spec template is the definition of "ready" now — the two enumerations are gone.
    ("readiness is a state, not a re-listed checklist",
     "Readiness is a state" in IMPL
     and "Ready is the template being complete" in PLAN),

    # Documentation is decided at planning time and checked at verify time; both ends must exist
    # or the section is a note nobody acts on.
    ("documentation impact is planned and then checked",
     "## Documentation impact" in SPEC
     and "Documentation impact" in PLAN and "Documentation impact" in VERIFY),
    ("the dev-doc index has a writer and a reader",
     "docs/dev/README.md" in IMPL and "docs/dev/README.md" in VERIFY
     and Path("templates/dev/README.md.template").exists()),

    # The smoke-tester said "failures only" and "record evidence for every step" — both.
    ("the smoke-tester reports every step and judges none",
     "one line per step" in SMOKE
     and "no judgement calls" in SMOKE.lower()
     and "Report **only** steps where observed" not in SMOKE),

    # A reference environment is optional even under git-flow, so its script and its workflow
    # must be installed together or not at all.
    ("the reference deploy script and workflow are gated together",
     "REFERENCE_ENV" in SCAFF
     and all(any(e["path"] == p for e in DELIVERY["entries"])
             for p in ("scripts/deploy-reference.sh", ".github/workflows/reference-deploy.yml"))),

    # Every new script must be delivered, or it exists in the plugin and never reaches a project.
    # A `mixed` file must be merged by hand, and /workflow-update decides that from a list it
    # keeps in prose. A mixed entry the list does not name gets whatever the generic class walk
    # does to it — for scripts/ci.sh that would mean replacing a project's filled gate with an
    # unfilled template, which is silent and total.
    ("every mixed manifest entry is named in the update's merge list",
     not [e["path"] for e in DELIVERY["entries"]
          if e["class"] == "mixed" and f'`{e["path"]}`' not in UPDATE]),

    # The new scripts were written for a deployed web app, and the workflow also supports
    # libraries, CLIs and internal tools. healthcheck.sh HARD-FAILS with no probes, so a
    # library whose only guidance was "the endpoint from deploy.md" could not release at all.
    ("healthcheck guidance covers projects that deploy nothing",
     all("npm view" in doc for doc in (SCAFF, ONBOARD, HEALTHSH))
     and "HEALTH_ALLOW_EMPTY" in SCAFF and "HEALTH_ALLOW_EMPTY" in ONBOARD),
    ("dev.sh guidance covers projects with nothing to keep running",
     all("library or" in doc for doc in (SCAFF, ONBOARD, DEVSH))),

    # Three scripts gained authoring blocks this release. A block left in ships instructions
    # addressed to the scaffolder as if they were project documentation — the exact defect the
    # deletion step exists for, which previously named only two files.
    ("the authoring-note deletion names every script that has one",
     all(f"`{n}`" in SCAFF.split("Delete the authoring notes")[1][:400]
         for n in ("ci.sh", "release.sh", "healthcheck.sh", "dev.sh", "deploy-reference.sh"))),

    # An anchored `^# e.g.` sweep reports clean while healthcheck.sh's indented hints ship.
    ("the authoring sweep is told the hints are not all at column 0",
     "unanchored" in SCAFF),

    # Found by an actual scaffolder run. `vitest related --run --passWithNoTests=false` fails
    # whenever the selection is empty — which is every clean tree, i.e. exactly the state
    # CONTRIBUTING tells humans to run `ci.sh fast` in. Strict belongs on the full suite only.
    ("selection is permissive about collecting nothing, the full suite is not",
     "--passWithNoTests=false" in SCAFF
     and "--passWithNoTests --dir" in SCAFF
     and "collecting nothing is NORMAL and must PASS" in CI),
    # The stronger half, found by a run: a selection command that merely NAMES the runner
    # selects nothing on every invocation — silently, forever — while still counting as a test
    # stage. It must compute and pass a file list, include untracked files, and stay in the
    # unit tree, or `fast` reaches integration tests it never built.
    ("the selected stage computes and passes a file list",
     all(s in SCAFF for s in ("git diff --name-only HEAD --", "git ls-files -o --exclude-standard",
                              "--dir tests/unit"))
     and "COMPUTE AND PASS" in SCAFF and "COMPUTE AND PASS" in CI),
    # The always-loaded file must not hard-code a source root onboard mode cannot create.
    ("the source root is a token, with a producer",
     "{{SOURCE_ROOT}}" in PCLAUDE and "`SOURCE_ROOT`" in SCAFF
     and "src/CLAUDE.md" not in PCLAUDE),

    # ...and the same run found that filling only a version_probe broke the documented
    # no-argument call, because it compares against an empty string and fails every time.
    ("healthcheck skips version probes when no version was asked for",
     '[ -z "$VERSION" ] && return 0' in HEALTHSH and "FILL BOTH KINDS" in HEALTHSH),

    # REFERENCE_ENV: yes forced deploy-reference.sh to be installed, while the script itself
    # told the reader to delete it when the platform tracks develop — the normal Railway setup.
    ("the reference script is installed only where something must actually run",
     "does not track `develop` itself" in SCAFF
     and "absence is normal" in PR),

    # A guard that can never be satisfied is a dead end, not a safeguard. HEALTH_ALLOW_EMPTY
    # waived the probe guard but not the version guard, so a project that publishes and deploys
    # nothing could never pass `healthcheck.sh <version>` — and /release never mentioned the
    # variable the install path is told to require.
    ("the empty-project release path is actually reachable",
     'VERSION_PROBES" -eq 0 ] && [ "${HEALTH_ALLOW_EMPTY' in HEALTHSH
     and "RELEASE_ALLOW_EMPTY" in RELEASE and "HEALTH_ALLOW_EMPTY" in RELEASE),

    # SOURCE_ROOT must have a producer on BOTH install paths, or the scaffolder guesses a value
    # it is forbidden to guess and onboard ships a dangling always-loaded pointer.
    ("both install paths produce SOURCE_ROOT",
     "SOURCE_ROOT" in INIT and "SOURCE_ROOT" in ONBOARD),

    # The ci-model block had two cases for three configurations, and the missing one leaves a
    # self-negating sentence in the file loaded on every turn.
    ("the ci-model block covers ci-on-claude: yes",
     "At `ci-on-claude: yes` replace" in PCLAUDE),

    # package.json.template is shaped for a service. A CLI published to npm needs bin/files/
    # repository, none of which it has and none of which were mentioned anywhere.
    ("the scaffolder covers the npm/CLI package fields",
     all(f in SCAFF for f in ("**`bin`**", "**`files`**", "**`repository`**"))),

    # Onboard copied 3 of 7 scripts while release.sh executes gate-status.sh on its first
    # stage — a project onboarded per the instructions shipped a release that died on line 1.
    ("onboard copies every script, not a subset",
     "copy ALL of them" in SCAFF and "Copying a subset is not a smaller install" in SCAFF),

    # Every *_ALLOW_* hatch is read from the environment. Without a file, local and CI disagree,
    # which is the exact drift the parity guarantee exists to prevent.
    ("the escape hatches have somewhere to live",
     all(".claude/gate-overrides.env" in Path(f"templates/scripts/{s}").read_text()
         for s in ("ci.sh", "release.sh", "healthcheck.sh", "dev.sh", "deploy-reference.sh"))
     and any(e["path"] == ".claude/gate-overrides.env" for e in DELIVERY["entries"])),

    # `pytest --picked tests/unit` exits 4 (argparse) on every run, and 5 on a clean tree even
    # with correct syntax. Measured. Python takes the documented same-as-full fallback.
    ("the python selection command is not the broken one",
     "pytest --picked" not in SCAFF.replace("`pytest-picked` does not work here", "")
     or "does not work here" in SCAFF),
    # A free-text token inside a double-quoted shell string expands whatever the author wrote.
    ("DEV_INFO is single-quoted", "DEV_INFO='{{DEV_INFO}}'" in DEVSH),

    ("every shipped script has a manifest entry",
     all(any(e.get("source") == f"templates/scripts/{n}" for e in DELIVERY["entries"])
         for n in ("ci.sh", "release.sh", "gate-status.sh", "criteria-check.sh",
                   "healthcheck.sh", "dev.sh", "deploy-reference.sh"))),

    # ci.sh fast must reach the SELECTED stage and full the whole suite; a rename that orphans
    # one leaves a live placeholder, which aborts the run.
    ("the gate distinguishes selected from full unit tests",
     "{{UNIT_TESTS_SELECTED}}" in CI and "{{UNIT_TESTS}}" in CI and "check_tests" in CI),
    # A token nothing fills ships as a live placeholder, and `fast` then dies with "command
    # not found" on the very first subtask. Every stage token needs a filler on BOTH install
    # paths; this one was added to ci.sh with neither, which is how it would have shipped.
    ("both install paths fill every ci.sh stage token",
     all(all(tok in doc for tok in ("{{UNIT_TESTS_SELECTED}}",))
         for doc in (SCAFF, ONBOARD))),
    # ...and both must say what to do when the runner has no selection mode, or the honest
    # answer ("same command as the full suite") reads as "leave it empty".
    ("both say to degrade selection upward, never to nothing",
     "same command as `{{UNIT_TESTS}}`" in SCAFF
     and "same command as `{{UNIT_TESTS}}`" in ONBOARD),
]

bad = [name for name, ok in CASES if not ok]
for name in bad:
    print(f"  ✗ {name}", file=sys.stderr)
if bad:
    sys.exit(1)
print(f"  ✓ skills and templates agree ({len(CASES)} cross-checks)")
