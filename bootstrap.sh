#!/usr/bin/env bash
# claude-workflow bootstrap script
# Run from your project directory: bash /path/to/claude-workflow/bootstrap.sh
# Copies all static plugin files into the project's .claude/ directory.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)"

if [ "$TARGET_DIR" = "$PLUGIN_DIR" ]; then
  echo "Error: run this script from your project directory, not from the plugin directory." >&2
  echo "  cd /your/project && bash $0" >&2
  exit 1
fi

echo "claude-workflow bootstrap"
echo "  Plugin : $PLUGIN_DIR"
echo "  Target : $TARGET_DIR"
echo ""

# ── 1. Create standard directory structure ─────────────────────────────────────
mkdir -p \
  "$TARGET_DIR/.claude/agents" \
  "$TARGET_DIR/.claude/skills" \
  "$TARGET_DIR/.claude/hooks" \
  "$TARGET_DIR/.claude/memory" \
  "$TARGET_DIR/docs/specs/backlog" \
  "$TARGET_DIR/docs/specs/ready" \
  "$TARGET_DIR/docs/specs/completed" \
  "$TARGET_DIR/docs/workflow" \
  "$TARGET_DIR/docs/dev/adr" \
  "$TARGET_DIR/.github/workflows" \
  "$TARGET_DIR/.github/ISSUE_TEMPLATE" \
  "$TARGET_DIR/scripts"

# ── 2. Copy agents ─────────────────────────────────────────────────────────────
cp "$PLUGIN_DIR/agents/"*.md "$TARGET_DIR/.claude/agents/"

# ── 3. Copy skills (preserve {name}/SKILL.md structure) ───────────────────────
for skill_dir in "$PLUGIN_DIR/skills/"/*/; do
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$TARGET_DIR/.claude/skills/$skill_name"
  cp "$skill_dir/SKILL.md" "$TARGET_DIR/.claude/skills/$skill_name/SKILL.md"
done

# ── 4. Copy hook scripts ───────────────────────────────────────────────────────
cp "$PLUGIN_DIR/templates/hooks/"*.sh "$TARGET_DIR/.claude/hooks/"
chmod +x "$TARGET_DIR/.claude/hooks/"*.sh

# ── 5. Copy settings.json (only if not already present) ───────────────────────
if [ ! -f "$TARGET_DIR/.claude/settings.json" ]; then
  cp "$PLUGIN_DIR/templates/hooks/hooks.json" "$TARGET_DIR/.claude/settings.json"
fi

# ── 6. Copy claude-loop script ─────────────────────────────────────────────────
cp "$PLUGIN_DIR/templates/scripts/claude-loop.sh" "$TARGET_DIR/scripts/claude-loop.sh"
chmod +x "$TARGET_DIR/scripts/claude-loop.sh"

# ── 7. Write workflow-source.json with pluginPath for later cleanup ────────────
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
if command -v python3 &>/dev/null && [ -f "$PLUGIN_JSON" ]; then
  WORKFLOW_VERSION="$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('version','unknown'))")"
  WORKFLOW_REPO="$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('repository',''))")"
else
  WORKFLOW_VERSION="unknown"
  WORKFLOW_REPO=""
fi
TODAY="$(date +%Y-%m-%d)"

cat > "$TARGET_DIR/.claude/workflow-source.json" << EOF
{
  "repo": "$WORKFLOW_REPO",
  "version": "$WORKFLOW_VERSION",
  "installed": "$TODAY",
  "pluginPath": "$PLUGIN_DIR"
}
EOF

# ── 8. Done ────────────────────────────────────────────────────────────────────
echo "Installed:"
echo "  .claude/agents/       $(ls "$TARGET_DIR/.claude/agents/" | wc -l | tr -d ' ') agents"
echo "  .claude/skills/       $(ls "$TARGET_DIR/.claude/skills/" | wc -l | tr -d ' ') skills"
echo "  .claude/hooks/        $(ls "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ') hook scripts"
echo "  scripts/claude-loop.sh"
echo "  .claude/workflow-source.json (v$WORKFLOW_VERSION)"
echo ""
echo "Next steps:"
echo "  1. Open Claude Code in this directory:  claude"
echo "  2. Run the bootstrap skill:             /bootstrap"
