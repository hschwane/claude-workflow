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
3. **Create** `docs/specs/backlog/{TYPE}-{NNN}-{kebab-title}.md` **from `docs/specs/spec.md.template`** — copy it and fill the frontmatter (`id`, `type`, `status: draft`, `version` or `~`, `created`/`updated` = today, leaving `test_scope: ~` and `github_issue: ~` for `/plan` and step 4). Restating the frontmatter here is how it drifts from the template every other skill reads; if the template is missing, say so rather than inventing the fields.

   Body: for a feature, the Goal user story plus the description with unknowns marked `[?]`; for a bug, Observed / Expected / Repro. Leave Acceptance Criteria as `- [ ] (defined in /plan)`.

4. **GitHub** (skip if the `github` setting in `CLAUDE.md` is `no`, or there is no github remote): `gh issue create --title "{title}" --label "{type},backlog" --body-file "{spec}"`, then set `github_issue:` in the frontmatter.
5. **Commit**: `docs(specs): draft {TYPE}-{NNN}  [skip ci]`.
6. **Report**: `Created {TYPE}-{NNN}: "{title}" — next: /plan {TYPE}-{NNN}`.
