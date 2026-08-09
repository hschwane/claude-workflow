"""Execute the per-language stage commands the scaffolder prescribes.

Three severe defects shipped because nothing ever RAN these commands — they were prose in a
table, reviewed and re-reviewed and wrong every time:

    vitest related --run --passWithNoTests=false   exit 1 on any clean tree
    vitest related --run --passWithNoTests         selects nothing, forever, silently
    uv run pytest --picked tests/unit              exit 4, argparse, every invocation

`_check_consistency.py` cannot see these: it compares files to files, and these are claims
about the outside world. Each was caught only by a 20-minute agent run, and each was written
as the fix for the previous one.

Every row of the matrix below is a defect that actually shipped. It asserts **how many tests
ran**, not just the exit code, because "green having run nothing" and "green having run the
right tests" are the same exit code — and that is exactly where the worst one hid.

Slow (installs a real toolchain per language), so it is opt-in: ./scripts/check.sh --languages
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CI_TEMPLATE = (ROOT / "templates/scripts/ci.sh").read_text()
# A language is covered only if its toolchain is here. Never skip silently: an uncovered
# language reported as nothing is indistinguishable from a covered one that passed.
TOOLCHAIN = {"typescript": "npm", "python": "uv", "rust": "cargo", "cpp": "cmake"}


def sh(cmd, cwd, env=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True,
                          env={**os.environ, **(env or {})})


def fill_ci(stages, drop_tests=False):
    """Fill ci.sh from the language's declared stages, as the scaffolder is told to."""
    s = CI_TEMPLATE
    for token, cmd in stages.items():
        verb = "check_tests" if "TESTS" in token else "check"
        if cmd is None or (drop_tests and "UNIT_TESTS" in token):
            s = s.replace(f"{verb} {{{{{token}}}}}", "")
        else:
            s = s.replace(f"{verb} {{{{{token}}}}}", f"{verb} {cmd}")
    s = s.replace("prepare {{GENERATE_SOURCES}}", "prepare true")
    return s


def make_project(lang, spec, drop_tests=False):
    d = Path(tempfile.mkdtemp(prefix=f"langfix-{lang}-"))
    shutil.copytree(ROOT / f"languages/{lang}/fixture", d, dirs_exist_ok=True)
    (d / "scripts").mkdir()
    (d / "scripts" / "ci.sh").write_text(fill_ci(spec["stages"], drop_tests))
    if drop_tests:
        for p in d.rglob("*test*"):
            if p.is_file():
                p.unlink()
    for c in ("git init -q .", "git config user.email t@t", "git config user.name t"):
        sh(c, d)
    r = sh(spec["install"], d)
    if r.returncode != 0:
        shutil.rmtree(d, ignore_errors=True)
        return None, f"install failed: {(r.stderr or r.stdout)[-300:]}"
    sh("git add -A && git commit -qm init", d)
    return d, None


def run_gate(d, mode, spec):
    """Run the gate. Returns (exit code, tests reported, the line that explains a failure).

    A harness that says "failed" without saying why sends you back to reproduce it by hand,
    which is the whole cost this script exists to remove.
    """
    r = sh(f"bash scripts/ci.sh {mode}", d)
    out = r.stdout + r.stderr
    counts = [int(m) for m in re.findall(spec["test_count"], out)]
    why = next((l.strip() for l in reversed(out.splitlines()) if l.lstrip().startswith("✗")), "")
    return r.returncode, sum(counts), why


def check(lang):
    """The state matrix. Returns a list of (name, ok, detail)."""
    spec = json.loads((ROOT / f"languages/{lang}/stages.json").read_text())
    results = []

    def record(name, ok, detail=""):
        results.append((name, ok, detail))

    d, err = make_project(lang, spec)
    if err:
        return [(f"{lang}: fixture builds", False, err)]
    try:
        # 1. A dirty tree with a real change: fast must run at least one test.
        # The edit has to be FORMAT-CLEAN, or the format stage fails and the test proves
        # nothing about selection. Each language declares a snippet its own formatter accepts.
        src = d / spec["source_file"]
        src.write_text(src.read_text() + spec["touch"])
        rc, n, why = run_gate(d, "fast", spec)
        record("fast passes on a dirty tree", rc == 0, why or f"exit {rc}")
        record("fast actually executed a test", n >= 1, f"{n} tests ran")
        sh("git checkout -- . && git clean -qfdx -e .venv -e node_modules -e target", d)

        # 2. Clean tree, empty selection. THIS is the vitest --passWithNoTests=false defect:
        #    it is the state of every checkout, and CONTRIBUTING tells humans to run it.
        rc, _, why = run_gate(d, "fast", spec)
        record("fast passes on a clean tree (empty selection)", rc == 0, why or f"exit {rc}")

        # 3. A brand-new UNTRACKED test must be selected. This is the missing-file-list defect:
        #    `git diff` never lists an untracked file, so the test just written is skipped.
        # Deterministic: sorted(), and a declared test dir. An arbitrary iterdir() order made
        # this flaky, which in a harness is worse than a plain failure — it teaches you to re-run.
        tdir = d / spec["test_dir"]
        seed = sorted(p for p in tdir.iterdir() if p.is_file() and p.suffix != ".pyc")[0]
        # Declared per language: cargo derives a test-target name from the file stem, so
        # `brandnew.test.rs` is not a legal name there. A harness that invents filenames
        # fails for reasons that have nothing to do with the thing it is testing.
        new = tdir / spec["new_test_file"]
        new.write_text(seed.read_text().replace("adds", "brandnew"))
        rc, n, why = run_gate(d, "fast", spec)
        record("fast selects a brand-new untracked test", rc == 0 and n >= 1,
               why or f"{n} tests ran")
        new.unlink()

        # 4. A failing test must fail the gate — the anti-suppression guarantee.
        seed.write_text(seed.read_text().replace("5", "6"))
        rc, _, _w = run_gate(d, "full", spec)
        record("a failing test fails the gate", rc != 0, f"exit {rc}")
        # Restore from git, not from remembered text: the tree is the authority, and a
        # half-restored fixture made the next case fail for a reason it does not test.
        # -x removes IGNORED files too. Without it pytest reuses the rewritten bytecode in
        # __pycache__ and the restored test still fails — a stale-cache ghost that looks
        # exactly like a real defect. Keep the installed dependencies.
        sh("git checkout -- . && git clean -qfdx -e .venv -e node_modules -e target", d)

        # 5. full runs the whole suite and passes.
        rc, n, why = run_gate(d, "full", spec)
        record("full passes and runs the suite", rc == 0 and n >= 1,
               why or f"{n} tests ran")
    finally:
        shutil.rmtree(d, ignore_errors=True)

    # 6. A project with no tests at all: full must REFUSE. The zero-test guard.
    d2, err = make_project(lang, spec, drop_tests=True)
    if err:
        record("no-test project builds", False, err)
    else:
        try:
            rc, _, _w = run_gate(d2, "full", spec)
            record("full refuses a project with no tests", rc != 0, f"exit {rc}")
        finally:
            shutil.rmtree(d2, ignore_errors=True)
    return results


def main():
    langs = sorted(p.name for p in (ROOT / "languages").iterdir() if p.is_dir())
    only = sys.argv[1:] or langs
    failed = skipped = 0
    covered = []
    for lang in langs:
        if lang not in only:
            continue
        tool = TOOLCHAIN.get(lang)
        if tool and not shutil.which(tool):
            print(f"  ⚠ {lang}: SKIPPED — {tool} is not installed, so nothing here was checked")
            skipped += 1
            continue
        covered.append(lang)
        for name, ok, detail in check(lang):
            print(f"  {'✓' if ok else '✗'} {lang}: {name}" + (f" ({detail})" if detail else ""),
                  file=sys.stdout if ok else sys.stderr)
            failed += not ok
    missing = [l for l in TOOLCHAIN if l not in langs]
    if missing:
        print(f"  ⚠ no fixture yet for: {', '.join(sorted(missing))} — those stage commands are "
              f"still unverified prose")
        skipped += len(missing)
    if failed:
        print(f"✗ {failed} language stage check(s) failed", file=sys.stderr)
        return 1
    print(f"  ✓ prescribed stage commands run correctly — {len(covered)} language(s) covered"
          f"{f', {skipped} not' if skipped else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
