# claude-workflow Bootstrap

## For Claude

The user has pasted the quick-start prompt. Follow these steps:

1. Clone the plugin into a temporary directory (skip if it already exists):
   ```bash
   git clone https://github.com/hschwane/claude-workflow /tmp/claude-workflow
   ```

2. Run `bootstrap.sh` from the **current project directory** (not from inside the plugin):
   ```bash
   bash /tmp/claude-workflow/bootstrap.sh
   ```
   This copies agents, skills, hooks, and scripts into `.claude/`.
   If the script reports that files are already in place, that is fine — it is idempotent.

3. Read and follow all instructions in `.claude/skills/bootstrap/SKILL.md`.
   The file was just copied into the project; read it directly with the Read tool and execute
   every step — no session restart is needed.

---

## After Setup

The workflow is embedded in `.claude/`. No `--plugin-dir` is needed in future sessions.

| Task | Command |
|------|---------|
| Update the workflow inside a project | `/workflow-update` |
| Plugin development (live edits) | `claude --plugin-dir ~/.claude/plugins/claude-workflow` |
| Update the plugin itself | `cd /tmp/claude-workflow && git pull` |

## Legacy / Manual Method

The old `--plugin-dir` approach still works:
```
claude --plugin-dir /path/to/claude-workflow
/project-init    # new project
/project-onboard # existing project
```
Note: with this method, the plugin directory deletion offer at the end of onboarding is skipped
(the local path is not recorded in `workflow-source.json`).
