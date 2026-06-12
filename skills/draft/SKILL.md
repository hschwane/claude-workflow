---
name: draft
description: Add a raw feature idea or bug report as a minimal backlog entry in docs/specs/backlog/. Use when the user wants to capture an idea or bug without planning it yet, or when /brainstorm accepts an idea.
argument-hint: "feature|bug \"title\" [\"description\"]"
---

# Draft

Creates a raw, minimal backlog entry for a feature idea or bug report. No planning required — refinement happens later in `/refine`.

## Usage
```
/draft feature "Title of the feature"
/draft bug "Short description of the bug"
/draft feature "Title" "Optional longer description or context"
/draft feature "Title" phase:2
```

## Instructions

### 1. Parse Input
Extract from the user's message:
- `type`: `feature` or `bug`. If missing, ask: "Is this a feature or a bug?"
- `title`: the main description
- `description`: any additional context (optional)
- `phase`: integer 1–4 if provided as `phase:N` (optional; `~` if absent)

### 2. Determine Next ID
- List files in `docs/specs/backlog/`, `docs/specs/ready/`, `docs/specs/completed/`
- Find the highest existing `FEAT-NNN` or `BUG-NNN` number for the given type
- Increment by 1, zero-pad to 3 digits (e.g., `FEAT-007`)
- If no specs exist: start at `001`

### 3. Create Spec File
Path: `docs/specs/backlog/{FEAT|BUG}-{NNN}-{kebab-case-title}.md`

Use this template, filling in what you know:
```markdown
---
id: {TYPE}-{NNN}
type: {feature|bug}
status: draft
phase: {N if provided, else ~}
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
github_issue: ~
---

# {Title}

## User Story
As a [user], I want [goal], so that [benefit].
{If description provided: use it to fill in what you can. Mark uncertain parts with [?]}

## Acceptance Criteria
- [ ] [To be defined in /refine]

## Open Questions
<!-- To be resolved in /refine -->
```

For bugs, replace User Story with:
```markdown
## Bug Report
**Observed:** {what happens — from description or [to be filled]}
**Expected:** {what should happen}
**Steps to reproduce:**
1. [To be filled in /refine]
```

### 4. GitHub Integration (if available)
Check if GitHub remote exists: `git remote get-url origin`
If it points to GitHub (contains `github.com`):
- Create issue: `gh issue create --title "{title}" --label "{type},backlog" --body-file "{spec-file}"` (label `feature` or `bug` matching the type)
- Note the returned issue number
- Update spec frontmatter: `github_issue: {number}`

### 5. Report Result
Print:
```
Created {TYPE}-{NNN}: "{title}"
File: docs/specs/backlog/{filename}
{If GitHub: Issue: #{number} — {url}}

Next: /refine {TYPE}-{NNN}   to define requirements
```
