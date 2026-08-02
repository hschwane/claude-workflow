---
name: pr
description: The merge skill — lands a finished feature branch on the integration branch, as a GitHub PR or as a local fast-forward, with the same gates either way. Under git-flow it targets develop; under main-only there is nothing to merge into but the trunk, so it hands over to /release.
argument-hint: "(no arguments — the target is always the integration branch)"
---

# PR — the merge skill

**Every merge goes through here.** A local fast-forward is not a different path with lower
standards; it is this skill choosing the cheaper execution because the conditions allow it. Local
merging exists so a small project does not pay for GitHub ceremony it gets nothing from — never so
it gets a weaker gate.

**`/pr` always targets `develop`.** `/release` always targets the trunk. One fixed target each, so
neither has to be told where to merge, and neither can be pointed at the wrong branch.

## Usage
```
/pr
```

## Instructions

### 0. Under `main-only`, stop and hand over

Read `branching` in `CLAUDE.md`. If it is `main-only` there is no `develop`: the only branch to
land on is the trunk, and **landing on the trunk is releasing**. Say so and stop —

> This project is `main-only`, so a merge to the trunk is a release. Run `/release {patch|minor|major}`
> instead; it does the gates, the merge and the release in one step.

Do not merge to the trunk from here. Under `main-only` a platform watching that branch deploys the
moment the merge lands, so a merge outside `/release` ships unversioned code and leaves the release
gate running after users already have it.

Nothing is lost by batching: several tickets can share one branch and release together.

### 1. Verify

`/verify pr`. It runs the gate and the review at the right depth, skips what is provably still
valid for this exact tree, and scopes the review to what changed since the last one. Do not restate
those rules here — one skill owns them.

Before that, bring the branch up to date with its target: `git fetch origin develop && git merge
origin/develop --no-edit`. Resolve conflicts locally. **Do this first**, because it is exactly the
thing that invalidates the recorded gate, and `/verify` will then notice.

If `/verify pr` reports `## Blocked` or a red gate, stop on the failure.

### 2. Choose the execution

| Condition | Execution |
|---|---|
| The ticket lives on GitHub — a linked issue, or the project tracks work there | **Open a real PR.** |
| No GitHub ticket **and** every gate ran green locally | **Local fast-forward.** |

Gate strictness is identical. What differs is where the evidence is written down and who can read
it — which is the whole reason a tracked ticket gets a PR.

**Real PR.** Look for a template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`,
`docs/`) and populate its sections; otherwise write what changed, why, and **how it was verified —
the gate result, the review depth and outcome, the smoke result, and any fix made in response**.
That record is the point: a reviewer arrives knowing what has already been checked. Then
`gh pr create --base develop --head {branch}`.

A gate that genuinely could not run locally — a platform you do not have, a matrix you cannot
reproduce — runs in Actions instead: `gh workflow run ci.yml --ref {branch}`, and record the result
in the PR. That is the only reason to wait on CI. Claude's commits carry `[skip ci]`, so nothing
runs on the push itself; never sleep-poll for checks that will not report.

**Local fast-forward.** `git merge --ff-only {branch}` onto `develop`, then push. If it cannot
fast-forward, the branch is behind — go back to step 1, which re-verifies the merged result rather
than assuming it is fine.

### 3. Merge

For a PR: `gh pr merge --squash`, with the squash message set explicitly and `[skip ci]` appended
unless `ci-on-claude: yes`. Do not use `--auto` expecting a skipped check to report — a skipped
required check sits Pending forever.

Ask before merging when a conflict needed non-trivial resolution or the base requires human
approval. Otherwise merge: landing the branch is what `/pr` was invoked to do.

### 4. Post-merge — update the reference environment

Only where a reference environment exists (git-flow, and the project chose to have one). It follows
`develop`, so it is stale the moment this merge lands.

If `scripts/deploy-reference.sh` exists, run it, then `scripts/healthcheck.sh --env reference`.

**Its absence is normal, not a gap.** A platform that watches `develop` itself deploys on the push, so there is nothing to run — just verify with `scripts/healthcheck.sh --env reference` once it has settled. `docs/dev/deploy.md` says which case this project is.

If you do not run it, push the merge commit **without** `[skip ci]` so `reference-deploy.yml` does
it instead. A workflow alone cannot be relied on here: `[skip ci]` suppresses *every* workflow for
that commit, not just CI, so a marked merge would silently stop the reference environment tracking
`develop` — with nothing reporting it. Local first, CI as the fallback, exactly as everywhere else.

### 5. Report
Branch, execution (PR URL or local ff), verify outcome, reference-environment state.
