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
     and (not MOD or all(s in MOD for s in STATUSES))),
    ("spec, decisions and the mod agree on the issue labels",
     all(l in SKILLS["spec"] and l in DECISIONS for l in LABELS)
     and (not MOD or all(l in MOD for l in ("wf-spec", "wf:ready", "wf:in-progress")))),
    ("the mod submits commands that exist",
     not MOD or ("command: `wf:${verb}`" in MOD
                 and all(f"'{c}'" in MOD and c in SKILLS for c in ("deliver", "gauntlet")))),
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
