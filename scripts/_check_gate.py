"""Assert the shipped gate scripts cannot report a pass they did not earn.

Every case here was a real defect at some point. They are asserted rather than
trusted because each one was reintroduced by a later well-meaning edit.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CI = Path("templates/scripts/ci.sh").read_text()
REL = Path("templates/scripts/release.sh").read_text()
HEALTH = Path("templates/scripts/healthcheck.sh").read_text()
DEPREF = Path("templates/scripts/deploy-reference.sh").read_text()
GATEST = Path("templates/scripts/gate-status.sh").read_text()
CRIT = Path("templates/scripts/criteria-check.sh").read_text()


CHECK_STAGES = ("FORMAT_CHECK", "LINT", "TYPECHECK")
TEST_STAGES = ("UNIT_TESTS", "UNIT_TESTS_SELECTED", "INTEGRATION_TESTS", "E2E_TESTS")


def _fill(s, token, cmd):
    """Fill one stage whatever its prefix — `check` or `check_tests`."""
    for verb in ("check_tests", "check"):
        s = s.replace(f"{verb} {{{{{token}}}}}", f"{verb} {cmd}" if cmd is not None else "")
    return s


def ci(prepare="true", stages="true", full=True, soften=False, empty=False, tests=True):
    s = CI.replace("prepare {{GENERATE_SOURCES}}", f"prepare {prepare}")
    for k in CHECK_STAGES:
        s = _fill(s, k, stages)
    # Order matters: _fill is a one-shot replace, so a stage filled here can no longer be
    # deleted below. Decide full-only stages FIRST, or `full=False` silently keeps them and
    # the "full with no full-only stages" case passes for the wrong reason.
    for k in ("BUILD", "INTEGRATION_TESTS", "E2E_TESTS"):
        s = _fill(s, k, ("true" if tests or k == "BUILD" else None) if full else None)
    for k in TEST_STAGES:
        # `tests=False` deletes only the test stages — the shape of a gate whose format, lint
        # and typecheck stages are all present and green over code nothing has ever run.
        s = _fill(s, k, stages if tests else None)
    if soften:
        s = s.replace("check true", 'check sh -c "exit 3" || true', 1)
    if empty:
        s = re.sub(r"^\s*check(_tests)? \S.*\n", "", s, flags=re.M)
    return s


def rel(publish="echo ok", health="echo ok", empty=False):
    s = REL.replace('"$(dirname "$0")/ci.sh" full', "true")
    if empty:
        # every step deleted — what a project that publishes and deploys nothing produces
        return re.sub(r"^\s*step \S.*\n", "", s, flags=re.M)
    s = s.replace("step {{PUBLISH}}", f"step {publish}").replace("step {{HEALTHCHECK}}", f"step {health}")
    return re.sub(r"^\s*step \{\{[A-Z_]+\}\}\s*\n", "", s, flags=re.M)


def run(script, *args, name="ci.sh", env=None):
    """Run a filled script from a faithful layout: <tmp>/scripts/<name>, invoked from <tmp>.

    The layout is not incidental. Both scripts open with `cd "$(dirname "$0")/.."` and then
    assert they landed in a repo root, so a script dropped at the temp-dir root would cd
    ABOVE the sandbox and every case here would fail for that reason instead of the one it
    tests. Getting this right is also what makes the cwd-independence guarantee testable.
    """
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "scripts").mkdir()
        p = Path(d) / "scripts" / name
        p.write_text(script)
        e = {**os.environ, **(env or {})}
        return subprocess.run(["bash", str(p), *args], capture_output=True, cwd=d, env=e).returncode


def run_at_root(script, *args, name="ci.sh"):
    """Run the script from a layout where the parent dir is NOT a repo root.

    Dropping it at <tmp>/nested/<name> makes `cd "$(dirname "$0")/.."` land in <tmp>, which we
    own and know is empty — the same end state as a missing `dirname`, without stripping PATH.
    Landing in a directory we do not control (/tmp) would make this pass or fail on whatever
    happens to be lying there. The gate must refuse rather than check an unrelated tree.
    """
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "nested").mkdir()
        p = Path(d) / "nested" / name
        p.write_text(script)
        return subprocess.run(["bash", str(p), *args], capture_output=True, cwd=d).returncode


def health(prod="probe true", *args, env=None):
    s = HEALTH.replace("{{HEALTHCHECK_PRODUCTION}}", prod).replace("{{HEALTHCHECK_REFERENCE}}", "probe true")
    return run(s, *args, name="healthcheck.sh", env=env)


def depref(ref="app-ref", prod="app-prod", steps="step true", env=None):
    s = (DEPREF.replace("{{REFERENCE_TARGET}}", ref).replace("{{PRODUCTION_TARGET}}", prod)
               .replace("{{DEPLOY_REFERENCE}}", steps))
    return run(s, name="deploy-reference.sh", env=env)


def gate_status(record=None, *, commits=("code",), dirty=False, want="full"):
    """Run gate-status.sh in a throwaway repo. `record` is formatted with the sha of commit 1."""
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "scripts").mkdir()
        (Path(d) / "scripts" / "gate-status.sh").write_text(GATEST)
        g = lambda *a: subprocess.run(["git", *a], cwd=d, capture_output=True)
        g("init", "-q", "."); g("config", "user.email", "t@t"); g("config", "user.name", "t")
        # last-gate.json is gitignored in a real project; untracked here would read as dirty.
        (Path(d) / ".gitignore").write_text(".claude/memory/\n")
        (Path(d) / "f.txt").write_text("a"); g("add", "-A"); g("commit", "-qm", "one")
        sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=d, capture_output=True,
                             text=True).stdout.strip()
        if record is not None:
            (Path(d) / ".claude" / "memory").mkdir(parents=True)
            (Path(d) / ".claude" / "memory" / "last-gate.json").write_text(record % sha)
        for c in commits[1:]:
            path = "docs/specs/x.md" if c == "spec" else "f.txt"
            (Path(d) / path).parent.mkdir(parents=True, exist_ok=True)
            (Path(d) / path).write_text(c)
            g("add", "-A"); g("commit", "-qm", c)
        if dirty:
            (Path(d) / "f.txt").write_text("changed")
        return subprocess.run(["bash", "scripts/gate-status.sh", want], cwd=d,
                              capture_output=True).returncode


def crit(spec):
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "scripts").mkdir()
        (Path(d) / "scripts" / "criteria-check.sh").write_text(CRIT)
        (Path(d) / "s.md").write_text(spec)
        return subprocess.run(["bash", "scripts/criteria-check.sh", "s.md"], cwd=d,
                              capture_output=True).returncode


_C2 = "## Acceptance Criteria\n- run x -> Z\n- bad w -> V\n\n"
_TBL = ("## Criteria verification\n| Criterion | Expected | Observed | Source |\n|---|---|---|---|\n"
        '| "run x -> Z" s.md:2 | Z | Z | manual run |\n'
        '| "bad w -> V" s.md:3 | V | V | test asserts V |\n')

VALID = '{"mode":"full","status":"passed","sha":"%s","dirty":false}'

CASES = [
    ("a filled gate passes",                      run(ci(), "full") == 0),
    ("a failing check fails the gate",            run(ci(stages='sh -c "exit 3"'), "fast") != 0),
    ("'|| true' cannot green a failed check",     run(ci(soften=True), "fast") != 0),
    ("a failing prepare step fails the gate",     run(ci(prepare='sh -c "exit 1"'), "fast") != 0),
    ("'|| true' cannot green a failed prepare",   run(ci(prepare='sh -c "exit 1" || true'), "fast") != 0),
    ("'full' with no full-only stages fails",     run(ci(full=False), "full") != 0),
    ("a gate with no checks fails",               run(ci(full=False, empty=True), "full") != 0),
    ("a filled release passes",                   run(rel(), "1.0.0", name="release.sh") == 0),
    ("a failing release step fails",              run(rel(publish='sh -c "exit 1"'), "1.0.0", name="release.sh") != 0),
    ("'|| true' cannot green a failed step",      run(rel(publish='sh -c "exit 1" || true'), "1.0.0", name="release.sh") != 0),
    ("a release with no steps fails",             run(rel(empty=True), "1.0.0", name="release.sh") != 0),
    # `cd "$(dirname "$0")/.."` fails OPEN — with dirname off PATH the expansion is empty and
    # `cd "/.."` succeeds, running the gate against the filesystem root. Both scripts assert
    # where they landed; run one from a layout with no repo root above it to prove it stops.
    ("the gate refuses to run outside a repo root",  run_at_root(ci(), "fast") != 0),
    # One level below CHECKS: delete only the test stages and format+lint+typecheck still
    # count 3, so the gate reported green over code no test had ever executed.
    ("a gate that ran no test stage fails",        run(ci(tests=False), "full") != 0),
    ("...unless TESTS_ALLOW_NONE acknowledges it", run(ci(tests=False), "full",
                                                       env={"TESTS_ALLOW_NONE": "1"}) == 0),
    # `fast` must reach the SELECTED stage, `full` the whole suite. Filling only the other
    # token leaves a live placeholder, which aborts with "command not found".
    ("fast runs the selected unit stage",          run(ci(), "fast") == 0),

    # --- healthcheck: reaching the service is not the same as the new build being live ---
    ("a healthy probe passes",                    health() == 0),
    ("a failing probe is unhealthy",              health("probe false") != 0),
    ("'|| true' cannot green a probe",            health("probe false || true") != 0),
    ("no probes verifies nothing → fails",        health("") != 0),
    ("...unless HEALTH_ALLOW_EMPTY says so",      health("", env={"HEALTH_ALLOW_EMPTY": "1"}) == 0),
    # The defect release.sh's authoring notes warned about for two releases and nothing enforced:
    # a probe that only proves the endpoint answers, asked to confirm a version.
    ("a version asked for with no version_probe fails",
     health("probe true", "1.4.0") != 0),
    ("a version_probe that matches passes",
     health('''version_probe sh -c 'echo 1.4.0 | grep -q "$0"' "$VERSION"''', "1.4.0") == 0),
    ("a version_probe that mismatches fails",
     health('''version_probe sh -c 'echo 1.4.0 | grep -q "$0"' "$VERSION"''', "9.9.9") != 0),
    ("an unknown environment fails",              health("probe true", "--env", "nope") != 0),

    # --- deploy-reference: the guard that makes it safe to run unattended ---
    ("a reference deploy to a distinct target runs", depref() == 0),
    ("deploying reference AT production refuses",    depref(ref="app-prod", prod="app-prod") != 0),
    # An unset production name would make the comparison above pass by knowing nothing.
    ("an unset production target refuses",           depref(prod="") != 0),
    ("a reference deploy with no steps refuses",     depref(steps="") != 0),
    ("'|| true' cannot green a reference step",      depref(steps="step false || true") != 0),

    # --- gate-status: the five-condition rule, as the executable everything else calls ---
    ("a clean matching record is valid",          gate_status(VALID) == 0),
    ("no record → run the gate",                  gate_status(None) != 0),
    ("a failed record → run the gate",
     gate_status('{"mode":"full","status":"failed","sha":"%s","dirty":false}') != 0),
    ("a fast record does not authorise skipping full",
     gate_status('{"mode":"fast","status":"passed","sha":"%s","dirty":false}') != 0),
    ("a full record does authorise skipping fast",
     gate_status(VALID, want="fast") == 0),
    # Recorded-dirty and dirty-now are NOT the same condition: the first catches a gate that
    # ran over edits later reverted, the second a green run followed by an edit — and editing
    # does not move HEAD, so every recorded field still matches.
    ("a record from a dirty tree → run the gate",
     gate_status('{"mode":"full","status":"passed","sha":"%s","dirty":true}') != 0),
    ("an edit after a green run → run the gate",  gate_status(VALID, dirty=True) != 0),
    ("a later code commit → run the gate",        gate_status(VALID, commits=("code", "code2")) != 0),
    ("a later spec-only commit stays valid",      gate_status(VALID, commits=("code", "spec")) == 0),
    ("a recorded sha that is not a commit fails",
     gate_status('{"mode":"full","status":"passed","sha":"deadbeef%.0s","dirty":false}') != 0),

    # --- criteria-check: /verify §3 is the one step with no skip rule, and nothing enforced it ---
    ("a complete criteria table passes",          crit(_C2 + _TBL) == 0),
    # The section is usually last in the file. A sed range with no closing heading runs to EOF,
    # so trimming its final line drops the last row — that off-by-one rejected correct specs.
    ("...whether it is the last section or not",  crit(_C2 + _TBL + "\n## Open Questions\n\n") == 0),
    ("a missing section fails",                   crit(_C2) != 0),
    ("a table short a row fails",                 crit(_C2 + "\n".join(_TBL.splitlines()[:-1]) + "\n") != 0),
    ("a header-only table fails",                 crit(_C2 + "## Criteria verification\n| a |\n|---|\n") != 0),
    ("a spec with no criteria fails",             crit("## Acceptance Criteria\n\n" + _TBL) != 0),
]

bad = [name for name, passed in CASES if not passed]
for name in bad:
    print(f"  ✗ {name}", file=sys.stderr)
if bad:
    sys.exit(1)
print(f"  ✓ gate + release refuse an unearned pass ({len(CASES)} cases)")
