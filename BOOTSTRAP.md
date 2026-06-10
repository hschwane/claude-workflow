# claude-workflow Bootstrap

## For Claude: follow these steps

1. Clone the plugin if `~/.claude/plugins/claude-workflow` does not already exist:
   ```bash
   git clone https://github.com/hschwane/claude-workflow ~/.claude/plugins/claude-workflow
   ```

2. Ask the user: **"Is this a new project (empty directory) or an existing project you want to onboard?"**

3. Based on the answer, read the matching skill file and execute every step in it as a task —
   the skill does not need to be registered, just follow its instructions directly:
   - **New project:** `~/.claude/plugins/claude-workflow/skills/project-init/SKILL.md`
   - **Existing project:** `~/.claude/plugins/claude-workflow/skills/project-onboard/SKILL.md`

   Note: subagents called by these skills (e.g. `code-explorer`) are not registered yet.
   Do their work inline in the main thread instead of spawning them.

4. When the skill completes, the workflow is fully set up in `.claude/`. Future sessions
   load it automatically — no `--plugin-dir` needed.

---

## For humans

After setup just run `claude` in your project directory — the workflow is embedded in `.claude/`.

| Task | Command |
|------|---------|
| Update the workflow inside a project | `/workflow-update` |
| Plugin development (live edits) | `claude --plugin-dir ~/.claude/plugins/claude-workflow` |
| Update the plugin itself | `cd ~/.claude/plugins/claude-workflow && git pull` |
