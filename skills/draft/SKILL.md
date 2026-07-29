---
name: draft
description: Capture a raw feature idea or bug as a minimal backlog entry in docs/specs/backlog/. No planning — that happens later in /plan.
argument-hint: "feature|bug \"title\" [\"description\"] [version:X]"
---

# Draft

Creates a minimal backlog entry. No planning required — `/plan` fleshes it out later.

## Usage
```
/draft feature "Title of the feature"
/draft bug "Short description of the bug"
/draft feature "Title" "Longer context" version:1.1.0
```

## Instructions

1. **Parse**: `type` (feature|bug — ask only if truly ambiguous), `title`, optional `description`, optional `version:X` (`~` if absent).
2. **Next ID**: scan `docs/specs/{backlog,ready,completed}/`, take the highest `FEAT-NNN`/`BUG-NNN` (both share one sequence), +1, zero-pad to 3 (`FEAT-007`). None yet → `001`.

   **This races across parallel sessions.** `CLAUDE.md` allows several sessions on different branches, and two that draft at the same time both see the same highest ID and both claim the next one. Before committing, re-scan and also check `git log --all --oneline -- docs/specs/ | head -20` for the id you picked; if it is taken, take the next free one. On a collision discovered later, renaming the *newer* spec is safe — nothing references it yet.
3. **Create** `docs/specs/backlog/{TYPE}-{NNN}-{kebab-title}.md` **from `docs/specs/spec.md.template`** — copy it and fill the frontmatter (`id`, `type`, `status: draft`, `version` or `~`, `created`/`updated` = today, leaving `test_scope: ~` and `github_issue: ~` for `/plan` and step 4). Restating the frontmatter here is how it drifts from the template every other skill reads; if the template is missing, say so rather than inventing the fields.

   Body: for a feature, the Goal user story plus the description with unknowns marked `[?]`; for a bug, Observed / Expected / Repro. Leave Acceptance Criteria as `- [ ] (defined in /plan)`.

4. **GitHub** (skip if the `github` setting in `CLAUDE.md` is `no`, or there is no github remote): `gh issue create --title "{title}" --label "{type},backlog" --body-file "{spec}"`, then set `github_issue:` in the frontmatter.
5. **Commit**: `git add docs/specs/ && git commit -m "docs(specs): draft {TYPE}-{NNN}  [skip ci]"`. Stage the specs directory explicitly — a bare commit here sweeps whatever else is in the working tree into a `docs(specs):` commit.
6. **Report**: `Created {TYPE}-{NNN}: "{title}" — next: /plan {TYPE}-{NNN}`.
