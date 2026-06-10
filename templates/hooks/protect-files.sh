#!/usr/bin/env bash
# Prevent Claude from editing sensitive or generated files.
# Receives Claude Code hook JSON on stdin: {"tool_name": "Write", "tool_input": {"file_path": "..."}}
# Exit 1 to block the edit, exit 0 to allow.
set -euo pipefail

INPUT=$(cat)

# Parse file path from stdin JSON
if command -v jq &>/dev/null; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
elif command -v python3 &>/dev/null; then
  FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
else
  FILE=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+' 2>/dev/null || true)
fi

[ -z "$FILE" ] && exit 0

FILE_NORM=$(realpath "$FILE" 2>/dev/null || echo "$FILE")

BLOCKED_PATTERNS=(
  "\.env$"
  "\.env\.local$"
  "\.env\.production$"
  "\.git/"
  "package-lock\.json$"
  "yarn\.lock$"
  "pnpm-lock\.yaml$"
  "poetry\.lock$"
  "Cargo\.lock$"
  "\.claude/workflow-source\.json$"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$FILE_NORM" | grep -qE "$pattern"; then
    echo "BLOCKED: $FILE is protected (matches pattern: $pattern)" >&2
    exit 1
  fi
done

exit 0
