# claude-workflow Bootstrap

## For Claude: follow these steps

1. The plugin should already be cloned to `~/.claude/plugins/claude-workflow` (you read this file from there). If not, clone it now:
   ```bash
   git clone https://github.com/hschwane/claude-workflow ~/.claude/plugins/claude-workflow
   ```

2. Ask the user: **"Is this a new project (empty directory) or an existing project you want to onboard?"**

3. Tell the user to restart Claude Code with the plugin loaded:
   ```bash
   claude --plugin-dir ~/.claude/plugins/claude-workflow
   ```
   Explain: skills and agents are registered at session start — a restart with `--plugin-dir` is required for `/project-init` and `/project-onboard` to be available.

4. After the user confirms they have restarted, instruct them to run:
   - **New project:** `/project-init`
   - **Existing project:** `/project-onboard`

---

## For humans

After `/project-init` or `/project-onboard` completes, the workflow is embedded in `.claude/` — just run `claude` normally. No `--plugin-dir` needed again.

| Task | Command |
|------|---------|
| Update the workflow inside a project | `/workflow-update` |
| Plugin development (live edits) | `claude --plugin-dir ~/.claude/plugins/claude-workflow` |
| Update the plugin itself | `cd ~/.claude/plugins/claude-workflow && git pull` |
