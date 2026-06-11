---
name: bootstrap
description: Entry point for installing claude-workflow — verifies setup, checks prerequisites, then routes to /project-init (new project) or /project-onboard (existing project)
disable-model-invocation: true
---

# Bootstrap

Entry point for setting up claude-workflow in a project. Run this after `bootstrap.sh` has been executed.

## Usage
```
/bootstrap
```

## Instructions

### 0. Verify bootstrap.sh Was Run
Check whether `.claude/agents/` exists and contains `.md` files:
```bash
ls .claude/agents/*.md 2>/dev/null | head -1
```

If the directory is missing or empty, stop and print:
```
bootstrap.sh has not been run yet.

Run it first from the plugin directory, e.g.:
  bash /tmp/claude-workflow/bootstrap.sh

Then run /bootstrap again (or ask Claude to read and follow .claude/skills/bootstrap/SKILL.md).
```

Read `.claude/workflow-source.json` and display:
```
claude-workflow v{version} ready — let's configure your project.
```

### 1. Prerequisites Check

**git:**
```bash
git --version
```
If git is not installed: print an error and stop — git is required.

**Git repository:**
```bash
git rev-parse --git-dir 2>/dev/null
```
If not a git repo, ask (AskUserQuestion): "This directory is not a git repository. Initialize one?"
Options: [Yes, run `git init` / No, I'll do it manually]
If yes: `git init`
If no: note this — GitHub-related steps later will be skipped.

**GitHub CLI** (optional — needed for repo creation and labels):
```bash
gh auth status 2>/dev/null
```
If `gh` is not installed or not authenticated: note it — the setup skills will remind the user to authenticate when GitHub features are needed.

### 2. New or Existing Project?
Ask (AskUserQuestion): "Is this a new project or an existing project you want to add the workflow to?"
Options: [New project (empty or near-empty directory) / Existing project (add workflow to existing code)]

If **New project**: read and follow all instructions in `.claude/skills/project-init/SKILL.md`
If **Existing project**: read and follow all instructions in `.claude/skills/project-onboard/SKILL.md`

### 3. Wrap-Up
After the chosen skill completes, offer to clean up the plugin directory, then print a completion summary.

**Offer plugin directory deletion:**
Read `.claude/workflow-source.json`. If the `pluginPath` field is set and that path still exists on disk:
  Ask (AskUserQuestion):
    "All workflow files have been installed into .claude/. The original plugin directory is no longer
     needed for this project:
       {pluginPath}
     Delete it now? (It can be re-cloned from GitHub any time.)"
  Options: [Yes, delete it / No, keep it]

  If **Yes**: run `rm -rf "{pluginPath}"` — then update `.claude/workflow-source.json` and remove
    the `pluginPath` key (the path no longer exists). Print: "Deleted {pluginPath}"
  If **No**: print: "Kept. You can delete it manually: rm -rf {pluginPath}"

If `pluginPath` is not set or the path does not exist: skip silently.

**Print completion summary:**
```
claude-workflow is fully set up. ✓

{If new project and backlog items were created:}
You have {N} items in your backlog. A good first step:
  /refine FEAT-001       start refining the first spec

{If new project with no backlog items yet, or existing project:}
Fill your backlog based on the project vision:
  /brainstorm

Other useful commands:
  /draft feature "title"   quickly capture an idea
  /refine FEAT-001         refine a specific spec into a ready-to-implement task
  /workflow-update         update to a newer workflow version later
```
