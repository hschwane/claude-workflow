---
name: implement
description: Implement a ready spec — write tests and code per subtask, fast-gate + commit each, then run /verify at feature-done
argument-hint: "FEAT-001 | BUG-042 | <github-issue-number>"
---

# Implement

Implements a ready spec subtask by subtask: write the code and its tests together, run the fast gate, commit (green commits only), tick the spec checkbox. When all subtasks are done, run `/verify`. State lives in the repo (branch + spec checkboxes + git log) — no separate checkpoint bookkeeping.

## Usage
```
/implement FEAT-001
/implement BUG-042
/implement 42          (GitHub issue number)
```

## Instructions

### 0. Pre-flight
Find the spec: by ID under `docs/specs/ready/`, or via `gh issue view {number}` for its linked spec. If it's still in `docs/specs/backlog/`, print "Not planned yet — run /plan {id} first" and stop.

Read the spec. Confirm it's ready to build: clear goal, **observable acceptance criteria**, subtasks listed, no open `[USER]` questions. If something essential is missing, run `/plan {id}` (or, for a tiny change, fill the gap inline) rather than guessing. Any preferences that apply were already referenced + folded into the spec by `/plan` — follow the spec; if it lists applied preference files, read those and honor them.

### 1. Branch
If not already on this spec's branch, branch from the integration branch (`develop` if it exists, else `main`/`master`):
```
git checkout {develop|main} && git pull
git checkout -b feature/{lowercase-id}-{kebab-title}
```
Set the spec frontmatter `status: in-progress`. If `github_issue` is set and `.claude/memory/decisions.md` does not say `GitHub integration: no`: move its labels to `in-progress` and drop a one-line "started on {branch}" comment.

Multiple sessions may run on different branches concurrently — that's fine; each owns its branch.

### 2. Implement each subtask (in order)

For each subtask:

**a) Write the code** to the spec's interface definitions (the contract — don't change them) and the project conventions (`src/CLAUDE.md` if present, else root `CLAUDE.md`; mirror existing patterns).

**b) Write its tests** — in the main session, scoped to *this* subtask's acceptance criteria. Test the **important behaviors**, not coverage for its own sake (see `docs/workflow/quality.md` for the project's test scope). Tests assert behavior, not implementation details.

**c) Fast gate** — invoke the `runner` agent with `scripts/ci.sh fast` (format + lint + typecheck/compile + the new & adjacent unit tests). It digests output so raw logs stay out of this context. Fix anything red before committing — **never commit on a red gate.**

**d) Commit** (green only) and push:
```
git add -A
git commit -m "{feat|fix}({scope}): {subtask description}  [skip ci]"
git push -u origin {branch}
```
Append `[skip ci]` **unless** the project's `ci-on-claude` decision is `yes` (libraries) — then omit it so CI runs on the push. (When GitHub integration is off, the marker is harmless.) Pushing per subtask is a cheap backup; the gate already ran locally.

**e) Tick the box** — `- [ ] #N` → `- [x] #N` in the spec. The spec's checkboxes + git log ARE the progress record; `/resume` reconstructs from them. Don't maintain a separate checkpoint.

**Implement every subtask — do not scope out the hard ones.** The spec's subtasks and acceptance criteria are the contract; a ticket is not done until they are all met. When a subtask turns out difficult, large, or messier than expected, that is **not** a reason to defer it, stub it, mark it "out of scope for later", or quietly narrow what you build — that is exactly the work. Do it fully; `/consult` if you're stuck; if it genuinely needs a human decision or a missing credential, write `## Blocked` (reason + what's required) and stop. Never trade "done" for "done except the hard/core part."

**If you get genuinely stuck** (same failure twice, or an architecture/security call): `/consult` before grinding. If it needs a human, write `## Blocked` to `.claude/memory/context-{branch}.md` (reason + what's required) and stop.

### 3. Feature done → verify

When every subtask box is ticked, run **`/verify`** (full gate + review + manual smoke for new features — see that skill). Fix anything it surfaces (and per the QA rule, turn any smoke-found bug into an automated test). Re-run `/verify` until clean.

### 4. Documentation (minimal, per policy)

Update only what the change actually affects (see the documentation policy in `CLAUDE.md`):
- **Technical:** keep `docs/dev/architecture.md` / ADRs accurate if structure, algorithms, APIs, or the data model changed. A pure bug fix usually needs nothing — but check.
- **User docs (`docs/user/`):** only if user-facing behavior changed (new/changed command, endpoint, UI, config). Prefer self-explanatory UI + in-app hints over prose.
- **Doc-comments:** only for function usage/params, class/file usage, and genuinely tricky algorithms/decisions.

Commit with `[skip ci]` per the same rule as 2d.

### 5. Complete
- Spec frontmatter `status: done`; `git mv docs/specs/ready/{file} docs/specs/completed/{file}`.
- If `github_issue` set and integration is on: comment "✅ implemented on `{branch}`".
- Commit (`docs(specs): complete {id}  [skip ci]`).
- If a `## Blocked` note was written for this branch, clear it.

Merging is a separate step — the caller (`/ship`) or the user handles it per the **Merge policy** (local git, no formal PR by default). Report:
```
Implemented ✓  {id} — {title}
Branch: {branch}   Subtasks: {N}   Gate: green   Verify: clean
Next: merge to {integration branch} (local, per Merge policy) — or /ship continues.
```
