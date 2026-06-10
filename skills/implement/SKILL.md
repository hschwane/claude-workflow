---
name: implement
description: Implement a ready spec — tests first in an isolated subagent, then code per subtask with a commit after each
argument-hint: "FEAT-001 | BUG-042 | <github-issue-number>"
disable-model-invocation: true
---

# Implement

Implements a ready spec using a two-phase sequential approach: first write failing tests in an isolated context (no access to impl code), then implement to make them pass. Commits after every subtask and saves progress checkpoints for resumability.

## Usage
```
/implement FEAT-001
/implement BUG-042
/implement 42          (GitHub issue number)
```

## Instructions

### 0. Pre-flight: Check DoR
Find the spec file:
- By ID: search `docs/specs/ready/` for a file matching the ID
- By GitHub issue: `gh issue view {number}` to find linked spec
- If found in `backlog/` (not `ready/`): print "This spec is not ready. Run /refine FEAT-001 first." and stop.

Read the spec file. Verify the Definition of Ready checklist:
- [ ] User Story is clear
- [ ] Acceptance criteria are testable (no vague terms like "should work")
- [ ] Interface definitions are present and complete
- [ ] All subtasks are listed
- [ ] No open questions remain
- [ ] RE sign-off ✓ and TP sign-off ✓

If DoR is not met: list what's missing and stop. Suggest `/refine {id}`.

### 1. Set Up Branch
Check current branch. If not on a feature branch for this spec, branch from the integration branch (`develop` if it exists — git flow; otherwise `main`/`master`):
```
git checkout {develop|main}
git pull
git checkout -b feature/{lowercase-id}-{kebab-title}
```
Example: `feature/feat-001-oauth-login`

Update spec frontmatter: `status: ready` → `status: in-progress`. File stays in `docs/specs/ready/`.

### 2. Save Initial Checkpoint
Write to `.claude/memory/context.md`:
```markdown
## In Progress
task: {SPEC_ID} - {title}
phase: implement
branch: {branch}
spec_file: {spec_path}
last_completed: "Started implementation"
next_step: "Phase 1: Write failing tests"
remaining_subtasks:
{list all subtasks}
saved_at: {timestamp}
```

### 3. PHASE 1 — Test Writer (isolated subagent)

Invoke the `test-writer` subagent. Pass it ONLY:
- The spec's **Acceptance Criteria** section
- The spec's **Interface Definitions** section
- 1-2 representative existing test files (for framework/style reference only — NOT for copying implementations)
- The project's test runner / tech stack from CLAUDE.md

**Do NOT provide the subagent with any existing implementation code or the full codebase.** The isolation is the point: tests must encode the spec, not the implementation.

The agent will write a complete test suite covering every acceptance criterion and place the tests in the correct location.

After the subagent writes the tests:
- Verify the test files are syntactically valid (run type-check if applicable)
- Run the tests — they should FAIL (that's correct — there's no implementation yet)
  - If any tests PASS: warn the user that those might be testing existing code, not the new spec
- Commit the new test files: `git add -A && git commit -m "test({scope}): add tests for {title}"`

Update checkpoint: `last_completed: "Phase 1 complete — tests written and committed"`

### 4. PHASE 2 — Implement (main context, sequential)

Now implement each subtask in order. For each subtask:

**a) Read the subtask** from the spec. Understand what it requires.

**b) Implement** — write the code for this subtask. Follow:
- The interface definitions from the spec (these are the contract, don't change them)
- Project conventions from `src/CLAUDE.md` if it exists, otherwise from root `CLAUDE.md`
- Existing patterns in the codebase (check similar modules)

**c) Run ONLY this subtask's tests:**
- Identify which test cases correspond to this subtask (by acceptance criterion reference)
- Run them: the relevant test file/suite

If tests fail: fix the implementation. Do not proceed to the next subtask until these tests pass.

**d) Commit and push the subtask:**
```
git add -A
git commit -m "{type}({scope}): {subtask description}"
git push -u origin {branch}
```
Use `feat` for features, `fix` for bugs. Pushing the feature branch after every commit is fine and serves as a backup — the quality gate (CI + reviews) happens when merging via `/pr`, not on push.

**e) Update checkpoint:**
```markdown
## In Progress
task: {SPEC_ID} - {title}
phase: implement
branch: {branch}
spec_file: {spec_path}
last_completed: "Subtask #{N}: {description} — committed {hash}"
next_step: "Subtask #{N+1}: {description}"
remaining_subtasks:
  - #{N+1}: ...
saved_at: {timestamp}
```

This ensures `/resume` can pick up from exactly the right subtask.

### 5. Final Verification
After all subtasks are complete:

**a) Run ALL tests** (not just the ones for this spec): invoke the `test-runner` subagent to run the full suite — it returns a condensed failure report instead of flooding the main context with test output.
If any tests fail: fix based on the report (read the failing test files directly if needed), then re-run via `test-runner` until green.

**b) Run linter:**
- TypeScript: `npx eslint . && npx tsc --noEmit`
- Python: `ruff check . && mypy .`
- Rust: `cargo clippy && cargo fmt --check`
- C++: `cmake --build build && clang-tidy ...`

Fix any issues and commit: `git add -A && git commit -m "fix({scope}): address linter findings"`

### 6. Update Documentation
Invoke the `documentation-writer` subagent with:
- The spec (acceptance criteria + interface definitions)
- The implemented interfaces (read the actual source files)
- Current state of relevant docs (`docs/dev/architecture.md`, `docs/user/` if relevant)

The agent writes updated documentation. Review and apply the changes.

Commit: `git add docs/ && git commit -m "docs({scope}): update docs for {title}"`

### 7. Complete
- The spec file stays in `docs/specs/ready/` with `status: in-progress` in its frontmatter (it moves to `docs/specs/completed/` after the PR merges, handled by `/pr`)
- Clear `## In Progress` from `.claude/memory/context.md`

Report:
```
Implementation complete ✓
Spec: {id} — {title}
Commits: {N} subtasks + 1 test + 1 docs
Branch: {branch}
All tests: pass
Linter: clean

Next: /pr   to create a pull request
```
