# claude-workflow Bootstrap

## Quick Setup

1. **Run `bootstrap.sh`** from your project directory:
   ```bash
   bash /path/to/claude-workflow/bootstrap.sh
   ```
   This copies agents, skills, hooks, and scripts into `.claude/` — no AI needed.

2. **Open Claude Code** in your project directory:
   ```bash
   claude
   ```

3. **Run the bootstrap skill:**
   ```
   /bootstrap
   ```
   Claude will ask whether this is a new or existing project, then guide you through the full setup.

---

## For Claude: Follow These Steps

If you are Claude and a user has directed you here (or pasted the Quick Start prompt below):

1. Clone the plugin to a temp directory if not already done:
   ```bash
   git clone https://github.com/hschwane/claude-workflow /tmp/claude-workflow
   ```

2. Run `bootstrap.sh` from the **current project directory** (not from inside the plugin):
   ```bash
   bash /tmp/claude-workflow/bootstrap.sh
   ```
   This copies agents, skills, hooks, and scripts into `.claude/`.

3. Read and follow all instructions in `.claude/skills/bootstrap/SKILL.md`.
   (Skills are now available in `.claude/skills/`. You can read the SKILL.md directly
   even within this session — no restart needed.)

---

## After Setup

The workflow is embedded in `.claude/`. No `--plugin-dir` needed in future sessions.

| Task | Command |
|------|---------|
| Update the workflow inside a project | `/workflow-update` |
| Plugin development (live edits) | `claude --plugin-dir ~/.claude/plugins/claude-workflow` |
| Update the plugin itself | `cd ~/.claude/plugins/claude-workflow && git pull` |

## Legacy / Manual Method

The old `--plugin-dir` approach still works if you prefer it:
```
claude --plugin-dir /path/to/claude-workflow
/project-init    # new project
/project-onboard # existing project
```
Note: with this method, the plugin directory deletion offer at the end of onboarding is skipped (the local path is not recorded).
