---
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
Check current branch. If not on a feature branch for this spec:
```
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

### 3. PHASE 1 — Test Writer (context:fork, isolated)

Spawn a subagent with the following context ONLY:
- The spec section: Acceptance Criteria + Interface Definitions
- Existing test files (for pattern/framework reference only — NOT for copying implementations)
- The tech stack information from CLAUDE.md

**Do NOT provide the subagent with:**
- Any existing implementation code
- The full codebase

Invoke the `test-writer` agent (context:fork). Pass it ONLY:
- The spec's **Acceptance Criteria** section
- The spec's **Interface Definitions** section
- 1-2 representative existing test files (for framework/style reference)
- The project's test runner from CLAUDE.md

The agent's full instructions are in `.claude/agents/test-writer.md`. It will write a complete test suite covering every acceptance criterion, place tests in the correct location, and output the files.

After the subagent writes the tests:
- Verify the test files are syntactically valid (run type-check if applicable)
- Run the tests — they should FAIL (that's correct — there's no implementation yet)
  - If any tests PASS: warn the user that those might be testing existing code, not the new spec
- Commit: `git add tests/ && git commit -m "test({scope}): add tests for {title}"`

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

**d) Commit the subtask:**
```
git add -A
git commit -m "{type}({scope}): {subtask description}"
```
Use `feat` for features, `fix` for bugs.

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

**a) Run ALL tests** (not just the ones for this spec):
```
npm test     # or: pytest / cargo test / ctest
```
If any tests fail: diagnose and fix before continuing.

**b) Run linter:**
- TypeScript: `npx eslint . && npx tsc --noEmit`
- Python: `ruff check . && mypy .`
- Rust: `cargo clippy && cargo fmt --check`
- C++: `cmake --build build && clang-tidy ...`

Fix any issues and commit: `git add -A && git commit -m "fix({scope}): address linter findings"`

### 6. Update Documentation
Spawn `documentation-writer` agent (context:fork) with:
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
