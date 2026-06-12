# Claude Workflow Bootstrap

Instructions for Claude Code to install the **claude-workflow** plugin into a project — works in any Claude Code environment (cloud web app, VS Code extension, console CLI).

---

## For Claude: Read This Before Doing Anything Else

You are being asked to install the claude-workflow development workflow. Follow the steps below exactly. Do not skip steps. Do not ask the user to do things manually that you can do yourself.

---

## Step 1: Verify Prerequisites

**Check that `gh` (GitHub CLI) is available:**

```bash
gh --version
```

If `gh` is not found, stop immediately and tell the user:

> "`gh` (GitHub CLI) is required but not installed. Install it from https://cli.github.com, then re-run this bootstrap."

Do not proceed until `gh` is confirmed available.

**Check that `gh` is authenticated:**

```bash
gh auth status
```

If not authenticated, tell the user to run `gh auth login` and complete the login flow before continuing. Wait for confirmation that authentication succeeded before moving on.

---

## Step 2: Confirm the Target

Ask the user (AskUserQuestion):

1. **New or existing project?** — "new project" (you will run `/project-init`) or "existing project" (you will run `/project-onboard`)?
2. **Target directory** — the absolute path where the project lives (or where it should be created). Default: current working directory.

---

## Step 3: Clone the Plugin to a Temporary Location

Run this Bash command:

```bash
git clone https://github.com/hschwane/claude-workflow /tmp/claude-workflow-bootstrap 2>&1 || echo "CLONE_FAILED"
```

If the clone fails (no `git`, no network, `CLONE_FAILED`):
- Use WebFetch to download individual files from `https://raw.githubusercontent.com/hschwane/claude-workflow/master/` as needed in subsequent steps.
- Adapt file paths below to use the raw URL instead of a local path.

---

## Step 4: Load the Skill

Read the appropriate skill file:

| Scenario | File to read |
|----------|-------------|
| New project | `/tmp/claude-workflow-bootstrap/skills/project-init/SKILL.md` |
| Existing project | `/tmp/claude-workflow-bootstrap/skills/project-onboard/SKILL.md` |

Read it now, before proceeding.

---

## Step 5: Execute the Skill

Follow the instructions in the SKILL.md **exactly as if the user had typed `/project-init` or `/project-onboard`**.

When the skill instructions reference paths inside the plugin, resolve them as follows:

| Skill refers to… | Use this path |
|-----------------|---------------|
| `agents/` | `/tmp/claude-workflow-bootstrap/agents/` |
| `skills/` | `/tmp/claude-workflow-bootstrap/skills/` |
| `templates/` | `/tmp/claude-workflow-bootstrap/templates/` |
| `.claude-plugin/plugin.json` | `/tmp/claude-workflow-bootstrap/.claude-plugin/plugin.json` |

All files the skill copies into `.claude/` go into the **target project's** `.claude/` directory (from Step 1).

### Making skills and agents available mid-session

The skill will copy all agent and skill files into the project's `.claude/agents/` and `.claude/skills/` directories. Once copied, Claude Code picks them up automatically — you can invoke them by name (e.g. `code-explorer`) for the rest of the session without any reload or restart.

---

## Step 6: Clean Up

After the skill completes:

```bash
rm -rf /tmp/claude-workflow-bootstrap
```

The project is now **self-contained** — the full workflow is embedded in `.claude/`. Future sessions only need `claude` (no `--plugin-dir` flag).

---

## Summary

```
1. Verify gh is installed and authenticated — stop if not
2. Ask: new project or existing? Target directory?
3. git clone https://github.com/hschwane/claude-workflow /tmp/claude-workflow-bootstrap
4. Read /tmp/claude-workflow-bootstrap/skills/project-init/SKILL.md
   (or project-onboard/SKILL.md for existing projects)
5. Execute the skill instructions exactly
6. rm -rf /tmp/claude-workflow-bootstrap
```
