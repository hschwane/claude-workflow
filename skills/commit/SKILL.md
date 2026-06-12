---
name: commit
description: Create a quality-gated conventional commit (format + lint + type-check before committing). Use whenever changes should be committed in a project using this workflow.
argument-hint: "[optional commit message override]"
---

# Commit

Creates a quality-gated conventional commit for staged or specified changes.

## Usage
```
/commit
/commit "Optional manual message override"
```

## Instructions

### 1. Check for Changes
Run `git status` and `git diff --staged`.
If nothing is staged: run `git add -A` after confirming with the user that they want to stage all changes.

### 1b. Spec-Only Check

Run:
```bash
{ git diff --name-only HEAD; git diff --name-only --cached; } | sort -u | grep -v "^docs/specs/" | head -1
```

If this outputs **nothing** — every changed file is under `docs/specs/` — take the spec-only fast path:
- Skip steps 2a and 2b entirely (no linter or type-check needed for spec files)
- Generate a `docs(specs): …` commit message (step 3) and commit (step 4)
- Push on any branch, including `develop`, `main`, or `master` — spec-only changes are safe to commit directly to integration branches
- Jump to step 6 (report)

**Only use this path if you are 100% certain every changed file is under `docs/specs/`.** If there is any doubt, run the full quality gates.

### 2. Quality Gates (run in order, stop on failure)

**a) Linter** — detect language from staged files and run:
- TypeScript/JS: `npx eslint --fix {files}` then `npx prettier --write {files}`
- Python: `ruff check --fix {files}` then `ruff format {files}`
- Rust: `cargo fmt`
- C++: `clang-format -i {files}`
- Shell: `shfmt -w {files}`

**b) Type-check** (if applicable):
- TypeScript: `npx tsc --noEmit`
- Python: `mypy {changed-files}`

If any gate fails and auto-fix was not possible: report the errors and stop. Do NOT commit broken code.

**If a gate's tool is not available** (e.g. `npx eslint` fails because node_modules is not installed, or `ruff`/`mypy` is missing): skip that gate, print a clear warning ("⚠ eslint not available — lint gate skipped"), and continue with the commit. A missing tool is an environment gap, not broken code — but it must be visible, never silent.

After auto-fixes (eslint --fix, prettier, ruff format, etc.): re-stage the modified files with `git add` so the fixes are included in the commit.

### 3. Generate Commit Message
If no manual message was provided, analyze the staged diff and generate a conventional commit message:

Format: `type(scope): description`

Types:
- `feat` — new feature
- `fix` — bug fix
- `refactor` — code change that neither fixes a bug nor adds a feature
- `test` — adding or updating tests
- `docs` — documentation only
- `chore` — build process, dependencies, tooling
- `perf` — performance improvement
- `ci` — CI configuration

Rules:
- scope: the module/component affected (e.g., `auth`, `api`, `cli`) — optional but encouraged
- description: imperative mood, lowercase, no period ("add OAuth login", not "Added OAuth login.")
- max 72 characters on first line
- If multiple concerns: pick the primary one. If truly mixed, suggest splitting.

### 4. Execute Commit
```
git commit -m "{generated-message}"
```

### 5. Push (feature branches)
If on a feature/fix/chore branch: push it (`git push -u origin {branch}`). Pushing work branches after every commit is allowed and encouraged (backup, visibility) — the quality gate applies when merging via `/pr`. Never push directly to `develop`, `main`, or `master` — **exceptions**: `/release` performs the release merge, and the spec-only fast path (step 1b) allows pushing spec-only commits to any branch.

### 6. Report
Print the commit hash and message. Suggest next step if obvious (e.g., "Next: /pr to create a pull request").
