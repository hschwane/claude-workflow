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

### 2. Quality Gate — the canonical entrypoint
Run the project's **canonical fast gate** via the `runner` agent: `scripts/ci.sh fast` (format + lint + typecheck/compile + affected unit tests). This is the *same* command CI would run, so "passes locally" means "would pass in CI" — no drift. The runner digests output.

- If it's red: fix and re-run. **Do NOT commit on a red gate.**
- If `scripts/ci.sh` doesn't exist yet (older project): fall back to detecting and running the language's format+lint+typecheck directly, and note that the project should add a canonical entrypoint (`/project-onboard` or `/workflow-update` installs one).
- If a tool is genuinely missing (not installed): the runner reports it; skip that check with a visible warning, never silently. A missing tool is an environment gap, not broken code.

Re-stage any files the gate auto-fixed (`git add`) so the fixes are in the commit.

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

### 4. Execute Commit — with the CI-skip marker
Append `[skip ci]` to the message **unless** the project's `ci-on-claude` decision is `yes` (read `docs/workflow/decisions.md` / `.claude/memory/decisions.md`) — then omit it so CI runs on Claude's push. This is how Claude's own commits avoid spending Actions minutes (Claude already ran the identical `ci.sh`); human commits, which carry no marker, still trigger CI. When GitHub integration is off, the marker is harmless.
```
git commit -m "{message}  [skip ci]"      # omit the marker when ci-on-claude: yes
```
(A spec-only commit from step 1b uses `docs(specs): …  [skip ci]` and needs no gate.)

### 5. Push
Feature/fix branches: push (`git push -u origin {branch}`) — cheap backup, the gate already ran. Direct commits to `develop`/`main`/`master` are fine for spec-only changes and for local merges per the **Merge policy** (`/ship` and `/release` do this); otherwise work on a branch.

### 6. Report
Print the commit hash and message.
