"""Assert the facts that several files must agree on.

v4 keeps this small on purpose: only claims that cross file boundaries, where one file can
change and silently leave another describing something that no longer exists.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(".")
SKILLS = {p.parent.name: p.read_text() for p in Path("skills").glob("*/SKILL.md")}
DECISIONS = Path("skills/setup/decisions.md").read_text()
CLAUDE_T = Path("templates/CLAUDE.md.template").read_text()
CRITIC = Path("agents/critic.md").read_text()
CI = Path("templates/scripts/ci.sh").read_text()
WORKERS = Path("shared/workers.md").read_text()
MOD = Path("hooks/wf.tsx").read_text() if Path("hooks/wf.tsx").exists() else ""
GUIDE_DIR = Path("skills/guidelines")

# --- settings keys: the template ships them, decisions.md explains them, skills read them ---
KEYS = re.findall(r"^- ([a-z-]+): ", CLAUDE_T.split("<!-- wf:settings -->")[1], re.M)

# --- every plugin path a skill names must exist -------------------------------------------
REFS = sorted({m for t in list(SKILLS.values()) + [DECISIONS]
               for m in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([A-Za-z0-9_./-]+)", t)})
MISSING = [r for r in REFS if "<" not in r and not (ROOT / r.rstrip("/.")).exists()]

# --- the guidelines table and the reference files are the same set --------------------------
TABLE = set(re.findall(r"`references/([a-z-]+\.md)`", SKILLS["guidelines"]))
FILES = {p.name for p in (GUIDE_DIR / "references").glob("*.md")}

# --- the hint sweep in decisions.md, run against the scripts it governs --------------------
_m = re.search(r"grep -nE '([^']+)'", DECISIONS)
SWEEP = _m.group(1) if _m else None
FILLABLE = ("ci.sh", "release.sh", "healthcheck.sh")


def swept(name):
    r = subprocess.run(["grep", "-nE", SWEEP, f"templates/scripts/{name}"], capture_output=True, text=True)
    return [l.split(":", 1)[1] for l in r.stdout.splitlines()]


def hints(name):
    return [l for l in Path(f"templates/scripts/{name}").read_text().splitlines()
            if re.match(r"^\s*#\s*e\.g\.", l)]


STATUSES = ("draft", "ready", "in-progress", "done")
LABELS = ("wf-spec", "wf:draft", "wf:ready", "wf:in-progress")
LANGS = sorted(p.name for p in Path("languages").iterdir() if p.is_dir())

CASES = [
    ("the settings block has keys", len(KEYS) >= 5),
    ("decisions.md explains every settings key", all(f"`{k}`" in DECISIONS or k in DECISIONS for k in KEYS)),
    ("every ${CLAUDE_PLUGIN_ROOT} path a skill names exists", not MISSING),
    ("the guidelines table lists exactly the reference files", TABLE == FILES and TABLE),
    ("CLAUDE.md template points at the guidelines skill", "guidelines" in CLAUDE_T),
    # Spec status and issue labels are written by `spec`, moved by `deliver`, read by the mod.
    ("spec, deliver and the mod agree on the spec statuses",
     all(s in SKILLS["spec"] for s in STATUSES) and "in-progress" in SKILLS["deliver"]
     and (not MOD or all(f"'{s}'" in MOD.split('const ORDER', 1)[-1].split('\n', 1)[0] for s in STATUSES))),
    ("spec, decisions and the mod agree on the issue labels",
     all(l in SKILLS["spec"] and l in DECISIONS for l in LABELS)
     and (not MOD or all(l in MOD for l in ("wf-spec", "wf:ready", "wf:in-progress")))),
    ("the mod submits commands that exist",
     not MOD or ("command: 'wf:deliver'" in MOD and "deliver" in SKILLS)),
    # Found in the desktop app's cloud sessions: the pane was never drawn, /board said "opened".
    ("/board reports an unplaced pane honestly and falls back to text",
     not MOD or ("opened.isPlaced" in MOD and "Spec board not shown" in MOD and "boardText" in MOD)),
    # gauntlet starts from a goal or a design doc and writes its own specs.
    ("gauntlet takes no specs as input; spec has no design-doc or enrich mode",
     "spec ids" not in SKILLS["gauntlet"] and "enrich mode" not in SKILLS["gauntlet"]
     and "enrich mode" not in SKILLS["deliver"] and "design <topic>" not in SKILLS["spec"]),
    # The loop: gauntlet runs deliver's procedure by path, deliver spawns the critic, and the
    # critic is the one that gets the original bar.
    ("gauntlet follows deliver's file", "skills/deliver/SKILL.md" in SKILLS["gauntlet"]),
    ("deliver spawns the critic with the original bar",
     "`wf:critic`" in SKILLS["deliver"] and "original bar" in SKILLS["deliver"]),
    ("the critic judges against the original bar, not only the spec", "original bar" in CRITIC),
    ("the per-spec cap is 4 rounds and says what happens after",
     "4 rounds" in SKILLS["deliver"] and "new specs" in SKILLS["deliver"]
     and "another round" in SKILLS["deliver"]),
    ("gauntlet is bounded by budget and concurrency, not rounds",
     "wf_usage" in SKILLS["gauntlet"] and "seven_day" in SKILLS["gauntlet"]
     and "Concurrency" in SKILLS["gauntlet"]),
    ("the mod registers the wf_usage tool gauntlet calls", not MOD or "wf_usage" in MOD),
    ("onboard sends old-plugin projects to convert", "/wf:convert" in SKILLS["onboard"]),
    # The hint sweep: anchored after indentation, or it misses indented hints; anchored at all,
    # or it eats ci.sh's zero-test comment, which ends a line with "e.g.".
    ("the hint sweep finds every hint in the fillable scripts",
     bool(SWEEP) and all(swept(n) == hints(n) and swept(n) for n in FILLABLE)),
    ("the hint sweep spares ci.sh's zero-test comment",
     bool(SWEEP) and "in the stage itself, e.g." in CI
     and not any("in the stage itself, e.g." in l for l in swept("ci.sh"))),
    ("every language has a stages.json with the full schema",
     all(all(k in json.loads(Path(f"languages/{l}/stages.json").read_text())
             for k in ("stages", "install", "test_count", "touch", "source_file", "test_dir",
                       "new_test_file", "notes"))
         for l in LANGS)),
    # Found by a live onboard run: "PyPI, no deploy" produced no healthcheck, and release's last
    # step then had nothing to run.
    ("a published package gets a healthcheck, and release copes without one",
     "a published package needs it too" in DECISIONS and "No `healthcheck.sh`" in SKILLS["release"]),
    # Found by the live gauntlet run: a batch's diff judged against one spec read as scope drift.
    ("deliver and the critic both handle a batch's shared diff",
     "other specs the diff contains" in SKILLS["deliver"] and "not scope drift" in CRITIC),
    # Found by the live release run: a dist/ left from an earlier build was uploaded with the new one.
    ("the release build starts from an empty output directory", "rm -rf dist" in DECISIONS),
    # gauntlet: the user never writes specs; it talks until the loop can run, and the goal reaches
    # every builder as well as every critic.
    ("gauntlet talks until the loop can run, then writes its own specs",
     "Talk until the loop can run" in SKILLS["gauntlet"] and "the user never has to" in SKILLS["gauntlet"]),
    ("gauntlet hands the goal statement to every builder and critic",
     "Every builder and every critic receives the goal statement" in SKILLS["gauntlet"]),
    # A Projects coordinator starts skills through the model and routes the work to threads; a
    # normal session uses subagents. Every skill must be model-invocable and follow workers.md.
    ("every skill can be invoked by the model",
     all("disable-model-invocation" not in t.split("---", 2)[1] for t in SKILLS.values())),
    ("every procedure skill names the lead/worker split",
     all("${CLAUDE_PLUGIN_ROOT}/shared/workers.md" in t for n, t in SKILLS.items() if n != "guidelines")),
    ("workers.md covers threads, subagents, unattended briefs and landing",
     all(s in WORKERS for s in ("Projects coordinator", "threads", "subagents", "Talking stays with the lead",
                                "unattended", "Project settings › Plugins", "pull requests"))),
    ("gauntlet can release, through the release skill", "skills/release/SKILL.md" in SKILLS["gauntlet"]),
    ("setup starts from the executed fixtures", "languages/<lang>/fixture/" in SKILLS["setup"]),
    ("CI templates fill the branch list on both triggers",
     all(Path(p).read_text().count("branches: {{CI_BRANCHES}}") == 2
         for p in Path("templates/github").glob("ci-*.yml"))),
]

bad = [name for name, ok in CASES if not ok]
for name in bad:
    print(f"  ✗ {name}", file=sys.stderr)
if MISSING:
    print(f"    missing: {MISSING}", file=sys.stderr)
if bad:
    sys.exit(1)
print(f"  ✓ skills, agents and templates agree ({len(CASES)} cross-checks)")
