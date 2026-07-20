#!/usr/bin/env bash
# Auto-format edited files based on detected language.
# Receives Claude Code hook JSON on stdin: {"tool_name": "Write", "tool_input": {"file_path": "..."}}
set -euo pipefail

INPUT=$(cat)

# Parse file path from stdin JSON (try jq, then python3, then a sed fallback).
# Each step only runs if the previous left FILE empty — on Windows the Python
# App Alias makes `command -v python3` succeed while producing no output, so we
# must always fall through to sed rather than trusting any single branch.
FILE=""
if command -v jq &>/dev/null; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi
if [ -z "${FILE:-}" ] && command -v python3 &>/dev/null; then
  FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
fi
if [ -z "${FILE:-}" ]; then
  FILE=$(echo "$INPUT" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1 || true)
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
