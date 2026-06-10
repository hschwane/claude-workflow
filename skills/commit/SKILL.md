---
disable-model-invocation: true
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

### 5. Report
Print the commit hash and message. Suggest next step if obvious (e.g., "Next: /pr to create a pull request").
