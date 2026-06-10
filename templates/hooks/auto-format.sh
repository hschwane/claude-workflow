#!/usr/bin/env bash
# Auto-format edited files based on detected language.
# Receives Claude Code hook JSON on stdin: {"tool_name": "Write", "tool_input": {"file_path": "..."}}
set -euo pipefail

INPUT=$(cat)

# Parse file path from stdin JSON (try jq, python3, then fallback grep)
if command -v jq &>/dev/null; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
elif command -v python3 &>/dev/null; then
  FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
else
  FILE=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+' 2>/dev/null || true)
fi

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md|*.yaml|*.yml)
    if command -v prettier &>/dev/null; then
      prettier --write "$FILE" 2>/dev/null || true
    elif command -v npx &>/dev/null; then
      npx --yes prettier --write "$FILE" 2>/dev/null || true
    fi
    ;;
  *.py)
    if command -v ruff &>/dev/null; then
      ruff format "$FILE" 2>/dev/null || true
    fi
    ;;
  *.rs)
    if command -v rustfmt &>/dev/null; then
      rustfmt "$FILE" 2>/dev/null || true
    fi
    ;;
  *.cpp|*.cxx|*.cc|*.c|*.h|*.hpp)
    if command -v clang-format &>/dev/null; then
      clang-format -i "$FILE" 2>/dev/null || true
    fi
    ;;
  *.sh)
    if command -v shfmt &>/dev/null; then
      shfmt -w "$FILE" 2>/dev/null || true
    fi
    ;;
esac

exit 0
