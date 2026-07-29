"""Assert the shipped gate scripts cannot report a pass they did not earn.

Every case here was a real defect at some point. They are asserted rather than
trusted because each one was reintroduced by a later well-meaning edit.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CI = Path("templates/scripts/ci.sh").read_text()
REL = Path("templates/scripts/release.sh").read_text()


def ci(prepare="true", stages="true", full=True, soften=False, empty=False):
    s = CI.replace("prepare {{GENERATE_SOURCES}}", f"prepare {prepare}")
    for k in ("FORMAT_CHECK", "LINT", "TYPECHECK", "UNIT_TESTS"):
        s = s.replace(f"check {{{{{k}}}}}", f"check {stages}")
    if full:
        for k in ("BUILD", "INTEGRATION_TESTS", "E2E_TESTS"):
            s = s.replace(f"check {{{{{k}}}}}", "check true")
    else:
        s = re.sub(r"^\s*check \{\{(BUILD|INTEGRATION_TESTS|E2E_TESTS)\}\}\s*\n", "", s, flags=re.M)
    if soften:
        s = s.replace("check true", 'check sh -c "exit 3" || true', 1)
    if empty:
        s = re.sub(r"^\s*check \S.*\n", "", s, flags=re.M)
    return s


def rel(publish="echo ok", health="echo ok", empty=False):
    s = REL.replace('"$(dirname "$0")/ci.sh" full', "true")
    if empty:
        # every step deleted — what a project that publishes and deploys nothing produces
        return re.sub(r"^\s*step \S.*\n", "", s, flags=re.M)
    s = s.replace("step {{PUBLISH}}", f"step {publish}").replace("step {{HEALTHCHECK}}", f"step {health}")
    return re.sub(r"^\s*step \{\{[A-Z_]+\}\}\s*\n", "", s, flags=re.M)


def run(script, *args):
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "s.sh"
        p.write_text(script)
        return subprocess.run(["bash", str(p), *args], capture_output=True, cwd=d).returncode


CASES = [
    ("a filled gate passes",                      run(ci(), "full") == 0),
    ("a failing check fails the gate",            run(ci(stages='sh -c "exit 3"'), "fast") != 0),
    ("'|| true' cannot green a failed check",     run(ci(soften=True), "fast") != 0),
    ("a failing prepare step fails the gate",     run(ci(prepare='sh -c "exit 1"'), "fast") != 0),
    ("'|| true' cannot green a failed prepare",   run(ci(prepare='sh -c "exit 1" || true'), "fast") != 0),
    ("'full' with no full-only stages fails",     run(ci(full=False), "full") != 0),
    ("a gate with no checks fails",               run(ci(full=False, empty=True), "full") != 0),
    ("a filled release passes",                   run(rel(), "1.0.0") == 0),
    ("a failing release step fails",              run(rel(publish='sh -c "exit 1"'), "1.0.0") != 0),
    ("'|| true' cannot green a failed step",      run(rel(publish='sh -c "exit 1" || true'), "1.0.0") != 0),
    ("a release with no steps fails",             run(rel(empty=True), "1.0.0") != 0),
]

bad = [name for name, passed in CASES if not passed]
for name in bad:
    print(f"  ✗ {name}", file=sys.stderr)
if bad:
    sys.exit(1)
print(f"  ✓ gate + release refuse an unearned pass ({len(CASES)} cases)")
