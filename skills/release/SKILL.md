---
name: release
description: Cut a release — version bump and changelog before the code reaches the trunk, land it, run scripts/release.sh, tag, and confirm the live version with scripts/healthcheck.sh. Use when the user asks to release, publish or deploy a version.
argument-hint: "patch | minor | major | <version>"
---

# Release

**Lead and workers** (`${CLAUDE_PLUGIN_ROOT}/shared/workers.md`): run it yourself when you can push; otherwise — in a
Project — one thread runs sections 1–5 with the version in its brief and reports back. Releasing is
the user's call: start only when they asked for it.

Settings come from the `<!-- wf:settings -->` block in `CLAUDE.md` (`branching`, `trunk`,
`release`, `deploy`). `release: none` → say there is nothing to release and stop.

## 1. Pre-flight
- Clean tree; pull if a remote exists (`[ -n "$(git remote)" ] && git pull`).
- **Where from:** `git-flow` → from `develop`, which then merges into the trunk. `main-only` → from
  the branch being released, **before** it lands on the trunk — landing there *is* the release, so
  the version must be in the code first.
- Unmerged work branches (`git branch --no-merged <trunk>`) are not in this release: name them.
- `scripts/ci.sh full` green, with tests executed.

## 2. Version and changelog
- New version from the argument (semver bump of the manifest's version, or the literal version).
  Write it to the manifest (`npm version <bump> --no-git-tag-version`, `pyproject.toml`,
  `Cargo.toml`, …). No manifest version → ask for it.
- `CHANGELOG.md`: a new `## [x.y.z] - <date>` section at the top, built from the commits since the
  last tag (`LAST=$(git describe --tags --abbrev=0 2>/dev/null); git log ${LAST:+$LAST..}HEAD
  --oneline --no-merges` — the guard matters on the first release). Group Added / Changed / Fixed /
  Removed, one short line each. Read only the head of the file, never all of it. At a major bump,
  or once the file passes ~50 KB, move the closed entries to `docs/changelog/<major>.x.md`
  (cut only at a version heading) and leave a pointer line.
- Check the README's description and run instructions are still true.
- Commit `chore: release v<version>`.

## 3. Land it
`main-only`: fast-forward the trunk to the release commit (`git merge --ff-only`), or a PR merged
the same way — the trunk's tree must be the tree that passed the gate. `git-flow`: merge `develop`
into the trunk, then the trunk back into `develop`.

## 4. Run and tag
- `scripts/release.sh <version>` (gate, build, publish, migrations, deploy — whatever the project
  filled in). Or, where the project releases from CI, dispatch it:
  `gh workflow run release.yml -f version=<version>` and watch it to completion.
- `git tag v<version>` and push trunk, branches and tag if a remote exists. A rejected push (protected
  branch, proxy) → fall back to `gh api`; no remote → say so and go on.

## 5. Confirm it is live
Wait until the new version can be visible (a deploy builds, a registry propagates), then
`scripts/healthcheck.sh <version>` — it only passes when a probe actually compares the version.
No `healthcheck.sh` → check the version where it is published (registry page or API, the
deployed endpoint) yourself, say that you did it by hand, and offer to add the script.
Unhealthy → roll back to protect users, then diagnose and fix forward; a rollback alone is not done.

## 6. Report
Version, changelog section, release steps run, tag, the health result.
