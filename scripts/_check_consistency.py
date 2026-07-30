"""Assert claims the skills and agents make about each other actually hold.

Every case here is a contradiction that shipped at least once: two files giving
opposite instructions for the same file, or a spec describing a template that has
since changed under it. Prose drifts silently; these do not.
"""
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
    ("CI templates tokenise the whole branch list",
     all("branches: {{CI_BRANCHES}}" in Path(p).read_text()
         and "{{TRUNK_BRANCH}}" not in Path(p).read_text()
         for p in Path("templates/github").glob("ci-*.yml"))),

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
     and "The exception must be explicit" in PCLAUDE),
]

bad = [name for name, ok in CASES if not ok]
for name in bad:
    print(f"  ✗ {name}", file=sys.stderr)
if bad:
    sys.exit(1)
print(f"  ✓ skills and templates agree ({len(CASES)} cross-checks)")
