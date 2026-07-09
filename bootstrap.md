# Claude Workflow Bootstrap

Instructions for Claude Code to install the **claude-workflow** plugin into a project — works in any Claude Code environment (cloud web app, VS Code extension, console CLI).

---

## For Claude: Read This Before Doing Anything Else

You are being asked to install the claude-workflow development workflow. Follow the steps below exactly. Do not skip steps. Do not ask the user to do things manually that you can do yourself.

---

## Step 1: Verify Prerequisites

### 1a. Ensure `gh` is in PATH

Run:
```bash
gh --version
```

**If `gh` is found:** continue to 1b.

**If `gh` is not found**, search common install locations before giving up:

```bash
# Common locations to probe (run each; stop at the first hit)
/usr/local/bin/gh --version
/opt/homebrew/bin/gh --version          # macOS Apple Silicon Homebrew
~/.local/bin/gh --version
"$HOME/.local/bin/gh" --version
/usr/bin/gh --version
# Windows common paths:
"C:/Program Files/GitHub CLI/gh.exe" --version
"$LOCALAPPDATA/Programs/GitHub CLI/gh.exe" --version
```

If a working binary is found at a non-PATH location:
- Add the directory to `PATH` for the current session: `export PATH="$PATH:/found/dir"` (Bash) or `$env:PATH += ";C:\found\dir"` (PowerShell)
- Re-run `gh --version` to confirm it resolves
- Continue to 1b

If `gh` is not found anywhere, **try to install it** before stopping:

Detect the OS and run the appropriate install command:

| OS | Command to try |
|----|---------------|
| macOS (Homebrew available) | `brew install gh` |
| macOS (no Homebrew) | `curl -sL https://cli.github.com/packages/githubcli-archive-keyring.gpg \| …` — too complex; guide the user to run `brew install gh` or download from https://cli.github.com |
| Ubuntu / Debian | `sudo mkdir -p /etc/apt/keyrings && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \| sudo dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \| sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt update && sudo apt install gh -y` |
| Fedora / RHEL / CentOS | `sudo dnf install gh -y` (after `sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo`) |
| Windows (winget available) | `winget install --id GitHub.cli -e` |
| Windows (choco available) | `choco install gh -y` |
| Windows (scoop available) | `scoop install gh` |
| Any (go available) | `go install github.com/cli/cli/v2/cmd/gh@latest` |

After install, re-run `gh --version`. If it resolves, add its directory to PATH if needed and continue to 1b.

**Only stop if installation fails or no install path is available.** Tell the user exactly what was tried, what failed, and that they should install `gh` manually from https://cli.github.com and re-run bootstrap.

### 1b. Ensure `gh` is authenticated

```bash
gh auth status
```

If not authenticated, tell the user to run:
```bash
gh auth login
```
and complete the interactive login flow. Wait for confirmation that `gh auth status` passes before moving on.

---

## Step 2: Confirm the Target

Ask the user (AskUserQuestion):

1. **New or existing project?** — "new project" (you will run `/project-init`) or "existing project" (you will run `/project-onboard`)?
2. **Target directory** — the absolute path where the project lives (or where it should be created). Default: current working directory.

---

## Step 3: Clone the Plugin to a Temporary Location

If `/tmp/claude-workflow-bootstrap` already exists (the README's one-prompt install clones it before you read this file), skip the clone and continue with Step 4.

Otherwise run this Bash command:

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

All files the skill copies into `.claude/` go into the **target project's** `.claude/` directory (from Step 2).

### Making skills and agents available mid-session

The skill will copy all agent and skill files into the project's `.claude/agents/` and `.claude/skills/` directories. Once copied, Claude Code picks them up automatically — you can invoke them by name (e.g. `code-explorer`) for the rest of the session without any reload or restart.

---

## Step 6: Clean Up

After the skill completes:

```bash
rm -rf /tmp/claude-workflow-bootstrap
```

The project is now **self-contained** — the full workflow is embedded in `.claude/`. Future sessions only need `claude` (no `--plugin-dir` flag).

Tell the user:

> **Restart your Claude Code session now.**
> The workflow hooks, status line, and all skills are fully active only after a fresh session start. Close this session and reopen it in the project directory — everything will be ready.

Do not proceed with any further work in this session.

---

## Summary

```
1. Ensure gh is in PATH (search common locations, install if missing, only stop if all else fails)
   Then ensure gh is authenticated
2. Ask: new project or existing? Target directory?
3. git clone https://github.com/hschwane/claude-workflow /tmp/claude-workflow-bootstrap
4. Read /tmp/claude-workflow-bootstrap/skills/project-init/SKILL.md
   (or project-onboard/SKILL.md for existing projects)
5. Execute the skill instructions exactly
6. rm -rf /tmp/claude-workflow-bootstrap
```
