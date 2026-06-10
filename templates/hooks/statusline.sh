#!/usr/bin/env bash
# Status line: model | context % | session (5h) and weekly (7d) usage.
# Also caches the official rate_limits data to .claude/memory/usage-cache.json
# so usage-guard.sh can enforce the unsupervised usage threshold without
# any network access. Works without jq (targeted grep/sed scraping).
set -uo pipefail

INPUT=$(cat)
MEM=".claude/memory"
CACHE="$MEM/usage-cache.json"

json_obj() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*{[^}]*}" | head -1; }
json_num() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*-\{0,1\}[0-9][0-9.]*" | head -1 | sed 's/.*:[[:space:]]*//'; }
json_str() { sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" | head -1; }

if command -v jq &>/dev/null; then
  MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
  CTX=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
  P5=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
  R5=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // 0')
  P7=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
  R7=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // 0')
else
  MODEL=$(echo "$INPUT" | json_str display_name); MODEL=${MODEL:-Claude}
  CTX=$(echo "$INPUT" | json_obj context_window | json_num used_percentage | cut -d. -f1)
  F5=$(echo "$INPUT" | json_obj five_hour); S7=$(echo "$INPUT" | json_obj seven_day)
  P5=$(echo "$F5" | json_num used_percentage | cut -d. -f1)
  R5=$(echo "$F5" | json_num resets_at)
  P7=$(echo "$S7" | json_num used_percentage | cut -d. -f1)
  R7=$(echo "$S7" | json_num resets_at)
fi

# Cache normalized usage for usage-guard.sh (only when data is present)
if [ -n "${P5:-}" ] || [ -n "${P7:-}" ]; then
  mkdir -p "$MEM"
  printf '{"ts": %s, "five_hour": {"pct": %s, "resets_at": %s}, "seven_day": {"pct": %s, "resets_at": %s}}\n' \
    "$(date +%s)" "${P5:--1}" "${R5:-0}" "${P7:--1}" "${R7:-0}" > "$CACHE" 2>/dev/null || true
fi

LINE="$MODEL"
[ -n "${CTX:-}" ] && LINE="$LINE | ctx ${CTX}%"
[ -n "${P5:-}" ] && LINE="$LINE | 5h ${P5}%"
[ -n "${P7:-}" ] && LINE="$LINE | 7d ${P7}%"
# Show the unsupervised threshold when set
TH=$(sed -nE 's/^usage_threshold:[[:space:]]*([0-9]+).*/\1/p' "$MEM/settings.md" 2>/dev/null | head -1)
[ -n "$TH" ] && LINE="$LINE (limit ${TH}%)"
echo "$LINE"

exit 0
