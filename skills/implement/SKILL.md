---
name: implement
description: Implement a ready spec — tests first in an isolated subagent, then code per subtask with a commit after each
argument-hint: "FEAT-001 | BUG-042 | <github-issue-number>"
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

### 0.5 Apply Routing

Read the spec's `routing:` block and invoke the route skill named by `routing.implementation` (e.g. `route-sonnet-medium`) — it sets model + effort for the rest of this turn and records the tier in the checkpoint. If the block is missing or empty (older spec), invoke `route-sonnet-medium` and note it.

**Re-arm rule:** the tier reverts on every new turn. At the start of ANY later turn that continues this ticket (scheduled wakeup, return from a CI wait, `/resume`), re-invoke the route skill from the checkpoint's `tier:` line before doing work.

### 1. Set Up Branch
Check current branch. If not on a feature branch for this spec, branch from the integration branch (`develop` if it exists — git flow; otherwise `main`/`master`):
```
git checkout {develop|main}
git pull
git checkout -b feature/{lowercase-id}-{kebab-title}
```
Example: `feature/feat-001-oauth-login`

Update spec frontmatter: `status: ready` → `status: in-progress`. File stays in `docs/specs/ready/`.

If the spec has `github_issue` set and `.claude/memory/decisions.md` does NOT contain `GitHub integration: no`:
- `gh issue edit {github_issue} --remove-label ready --add-label in-progress`
- `gh issue comment {github_issue} --body "🔧 Implementation started on branch \`{branch}\`."`

### 2. Save Initial Checkpoint
Determine the context file path: run `git branch --show-current | sed 's|/|-|g'` to get `{branch}`, then write to `.claude/memory/context-{branch}.md` (keep it minimal — subtask progress lives in the spec file's checkboxes, not here):
```markdown
## In Progress
task: {SPEC_ID} - {title}
phase: implement
branch: {branch}
spec_file: {spec_path}
tier: {routing.implementation — kept current by the route skills; /resume re-arms from this line}
last_completed: "Started implementation"
next_step: "Phase 1: Write failing tests"
saved_at: {timestamp}
```

### 3. PHASE 1 — Test Writer (isolated subagent)

Invoke the `test-writer` subagent, passing the spec's `routing.test_writing` model as the per-invocation `model` parameter (its effort is pinned `medium`). Pass it ONLY:
- The spec's **Acceptance Criteria** section
- The spec's **Interface Definitions** section
- The spec's **Subtasks** list (for the gap check in Step 3 of the test-writer)
- 1-2 representative existing test files (for framework/style reference only — NOT for copying implementations)
- The project's test runner / tech stack from CLAUDE.md
- `TESTING_SCOPE`: read the "Konfigurierter Scope:" line from `docs/workflow/quality.md`, or the `Testing:` field from `.claude/memory/decisions.md`

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

**e) Update progress** (two small edits, ~50 tokens total):
1. Tick the subtask's checkbox in the spec file (`- [ ] #N:` → `- [x] #N:`) — **the spec is the single source of truth for remaining work**
2. Update only the changed lines in the branch context file (`.claude/memory/context-{branch}.md`): `last_completed`, `next_step`, `saved_at`

This ensures `/resume` can pick up from exactly the right subtask (it derives remaining work from the spec's unchecked boxes).

**Adaptive routing during implementation** (see the Adaptive Routing Policy in the project CLAUDE.md):

- **Escalate — medium threshold.** Not at first friction and never on gut feeling, but on clear signals: the same subtask failed twice with the same class of error, the TP plan demonstrably doesn't fit reality, or the work turns out architecture-/security-relevant beyond the spec. Then: **first invoke `/consult`** with the concrete question — the advisor usually unblocks on the top tier and steps back down. Only if the *remaining execution itself* needs more capability: invoke the route skill one notch up (sonnet-medium → sonnet-high → opus-medium → opus-high; ceiling `best-medium`) and record `actual: {tier} — escalated: {reason}` in the spec's routing block.
- **De-escalate — high threshold.** Only at a subtask boundary, only when the remaining work is clearly mechanical (plan fully made, repetitive application), one notch down, floor `sonnet-medium`.
- Announce every switch in one line with its reason. At most ~2 unplanned switches per turn, and only at phase boundaries — model switches invalidate the prompt cache.

**Context hygiene:** delegate bulky reading and test runs to subagents (`code-explorer`, `test-runner`) instead of pulling raw output into this context; don't re-read large files already processed; keep the checkpoint and spec checkboxes current after every subtask so automatic context compaction never loses state.

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
Decide the docs scope first:
- **Technical docs — always in scope**: `docs/dev/architecture.md`, ADRs, API/interface docs. Every implementation must leave the technical docs accurate (for a pure bug fix the agent may conclude nothing needs changing, but it must check).
- **User docs (`docs/user/`) — only when user-facing behavior changed**: new or changed CLI commands, endpoints, UI, configuration options, or visible behavior. For internal refactors and invisible bug fixes, leave user docs out of scope entirely — don't pass them as input.

Invoke the `documentation-writer` subagent with:
- The spec (acceptance criteria + interface definitions)
- The implemented interfaces (read the actual source files)
- Current state of in-scope docs only (`docs/dev/architecture.md` always; `docs/user/` only if user-facing)

The agent edits the documentation files itself. Review its changes with `git diff` and adjust if needed.

Commit: `git add docs/ && git commit -m "docs({scope}): update docs for {title}"`

### 7. Complete

Move the spec to completed:
- Update frontmatter: `status: in-progress` → `status: done`
- `git mv docs/specs/ready/{filename} docs/specs/completed/{filename}`
- If `github_issue` is set and decisions.md does NOT contain `GitHub integration: no`:
  - `gh issue comment {github_issue} --body "✅ Implementation complete on branch \`{branch}\`. PR incoming."`
- `git add docs/specs/ && git commit -m "docs(specs): complete {id}"`

Clear `## In Progress` from the branch context file (`.claude/memory/context-{branch}.md`).

Invoke `route-sonnet-medium` — implementation is done; whatever follows in this turn (opening the PR, waiting on CI, orchestration) must not keep running on the implementation tier.

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
