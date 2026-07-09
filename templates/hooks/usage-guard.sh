#!/usr/bin/env bash
# Soft token-budget guard for unsupervised mode.
#
# Reads the usage threshold from .claude/memory/settings.md (usage_threshold: NN).
# Usage data sources, in order:
#   1. .claude/memory/usage-cache.json — written by statusline.sh from the official
#      statusline JSON (rate_limits.five_hour/seven_day), refreshed continuously
#   2. The Anthropic OAuth usage endpoint (community-established fallback;
#      needs ~/.claude/.credentials.json) — cached for 60s
#   3. Fail-open: if usage cannot be determined, the guard never trips.
#
# No hard dependency on jq/python — uses targeted grep/sed JSON scraping as
# fallback (jq is preferred when available).
#
# Modes:
#   (default / hook)  PostToolUse hook: exit 0 = fine, exit 2 = threshold reached
#                     (stderr instructs Claude to pause via the wait loop)
#   --wait            Single wait cycle (~100s max): prints RESUME_OK when usage
#                     dropped below threshold-margin, else WAITING status.
#                     For local interactive sessions: Claude calls this repeatedly
#                     until RESUME_OK.
#   --check           One-shot, no internal sleep: prints RESUME_OK or WAITING
#                     immediately. For cloud/remote sessions that pause between
#                     checks with a scheduled wakeup instead of blocking on a
#                     Bash sleep loop — see /unsupervised skill.
#   --status          Print current usage and threshold (for /unsupervised status)
set -uo pipefail

MEM=".claude/memory"
SETTINGS="$MEM/settings.md"
CACHE="$MEM/usage-cache.json"
WAIT_MARKER="$MEM/usage-wait.active"
OFFER_MARKER="$MEM/usage-supervised-offered.active"
CRED="${CLAUDE_CREDENTIALS:-$HOME/.claude/.credentials.json}"
RESUME_MARGIN=20   # resume when usage <= threshold - margin (hysteresis)
MODE="${1:-hook}"

now() { date +%s; }
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# ── tiny JSON scraping helpers (fallback when jq is unavailable) ──────────────

json_obj() { # $1=key; stdin=json → the {...} object following "key": (flat objects only)
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*{[^}]*}" | head -1
}
json_num() { # $1=key; stdin=json fragment → first numeric value of key (or empty)
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*-\{0,1\}[0-9][0-9.]*" | head -1 | sed 's/.*:[[:space:]]*//'
}
json_str() { # $1=key; stdin=json → first string value of key (or empty)
  sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" | head -1
}

# ── settings ──────────────────────────────────────────────────────────────────

get_setting() { # $1=key → value or empty
  [ -f "$SETTINGS" ] || return 0
  sed -nE "s/^$1:[[:space:]]*([^[:space:]]+).*/\1/p" "$SETTINGS" | head -1
}

UNSUPERVISED=$(get_setting "unsupervised")
THRESHOLD=$(get_setting "usage_threshold")

# ── usage acquisition ─────────────────────────────────────────────────────────
# Normalized cache: {"ts":epoch,"five_hour":{"pct":N,"resets_at":epoch},
#                    "seven_day":{"pct":N,"resets_at":epoch}}

read_cache() { # sets P5 R5 P7 R7 TS from $CACHE; returns 1 on failure
  [ -f "$CACHE" ] || return 1
  local json f5 s7
  json=$(cat "$CACHE" 2>/dev/null) || return 1
  if command -v jq &>/dev/null; then
    local line
    line=$(echo "$json" | jq -r '[(.five_hour.pct // -1), (.five_hour.resets_at // 0),
      (.seven_day.pct // -1), (.seven_day.resets_at // 0), (.ts // 0)] | @tsv' 2>/dev/null) || return 1
    P5=$(echo "$line" | cut -f1); R5=$(echo "$line" | cut -f2)
    P7=$(echo "$line" | cut -f3); R7=$(echo "$line" | cut -f4); TS=$(echo "$line" | cut -f5)
  else
    f5=$(echo "$json" | json_obj five_hour); s7=$(echo "$json" | json_obj seven_day)
    P5=$(echo "$f5" | json_num pct); R5=$(echo "$f5" | json_num resets_at)
    P7=$(echo "$s7" | json_num pct); R7=$(echo "$s7" | json_num resets_at)
    TS=$(echo "$json" | json_num ts)
  fi
  P5=${P5:--1}; R5=${R5:-0}; P7=${P7:--1}; R7=${R7:-0}; TS=${TS:-0}
  return 0
}

iso_to_epoch() { # best effort; empty input → 0
  [ -z "${1:-}" ] && { echo 0; return; }
  date -d "$1" +%s 2>/dev/null || echo 0
}

fetch_oauth() { # query usage endpoint, rewrite $CACHE; best effort
  command -v curl &>/dev/null || return 1
  [ -f "$CRED" ] || return 1
  local token resp f5 s7 p5 r5 p7 r7
  if command -v jq &>/dev/null; then
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CRED" 2>/dev/null)
  else
    token=$(json_str accessToken < "$CRED")
  fi
  [ -z "$token" ] && return 1
  resp=$(curl -sf --max-time 10 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code/2.0 (usage-guard)") || return 1
  f5=$(echo "$resp" | json_obj five_hour); s7=$(echo "$resp" | json_obj seven_day)
  p5=$(echo "$f5" | json_num utilization); p7=$(echo "$s7" | json_num utilization)
  r5=$(iso_to_epoch "$(echo "$f5" | json_str resets_at)")
  r7=$(iso_to_epoch "$(echo "$s7" | json_str resets_at)")
  [ -z "$p5" ] && [ -z "$p7" ] && return 1
  printf '{"ts": %s, "five_hour": {"pct": %s, "resets_at": %s}, "seven_day": {"pct": %s, "resets_at": %s}}\n' \
    "$(now)" "${p5:--1}" "${r5:-0}" "${p7:--1}" "${r7:-0}" > "$CACHE"
}

get_usage() { # sets P5 R5 P7 R7; returns 1 if unknown
  local age
  if read_cache; then
    age=$(( $(now) - TS ))
    if [ "$age" -gt 60 ]; then
      fetch_oauth && read_cache || true
    fi
  else
    fetch_oauth && read_cache || return 1
  fi
  # stale data (>15 min) is as good as no data — fail open
  [ $(( $(now) - TS )) -gt 900 ] && return 1
  [ "${P5%.*}" = "-1" ] && [ "${P7%.*}" = "-1" ] && return 1
  return 0
}

max_pct() { # integer max of P5/P7 (floats truncated)
  local a=${P5%.*} b=${P7%.*}
  [ -z "$a" ] || [ "$a" = "-1" ] && a=0
  [ -z "$b" ] || [ "$b" = "-1" ] && b=0
  [ "$a" -ge "$b" ] && echo "$a" || echo "$b"
}

fmt_reset() { # $1=epoch → HH:MM or "?" (GNU and BSD date)
  if [ "${1:-0}" -gt 0 ] 2>/dev/null; then
    date -d "@$1" '+%H:%M' 2>/dev/null || date -r "$1" '+%H:%M' 2>/dev/null || echo "?"
  else
    echo "?"
  fi
}

usage_line() {
  echo "5h: ${P5%.*}% (resets $(fmt_reset "$R5"))  7d: ${P7%.*}% (resets $(fmt_reset "$R7"))"
}

# ── modes ─────────────────────────────────────────────────────────────────────

case "$MODE" in

  --status)
    if get_usage; then
      echo "Usage: $(usage_line)"
    else
      echo "Usage: unknown (no statusline cache, OAuth endpoint unavailable)"
    fi
    [ -n "$THRESHOLD" ] && echo "Threshold: ${THRESHOLD}% (resume below $((THRESHOLD - RESUME_MARGIN))%)" \
                        || echo "Threshold: not set"
    exit 0
    ;;

  --wait)
    # not configured → nothing to wait for
    if [ "$UNSUPERVISED" != "true" ] || [ -z "$THRESHOLD" ]; then
      echo "RESUME_OK (no usage threshold configured)"; rm -f "$WAIT_MARKER"; exit 0
    fi
    RESUME_AT=$(( THRESHOLD - RESUME_MARGIN )); [ "$RESUME_AT" -lt 5 ] && RESUME_AT=5
    for attempt in 1 2; do
      if ! get_usage; then
        echo "RESUME_OK (usage unknown — failing open)"; rm -f "$WAIT_MARKER"; exit 0
      fi
      if [ "$(max_pct)" -le "$RESUME_AT" ]; then
        echo "RESUME_OK — $(usage_line)"; rm -f "$WAIT_MARKER"; exit 0
      fi
      touch "$WAIT_MARKER"
      [ "$attempt" = "1" ] && sleep 90
    done
    echo "WAITING — usage above resume level (${RESUME_AT}%). $(usage_line)"
    echo "Run this command again (it sleeps ~90s per call) until it prints RESUME_OK."
    exit 0
    ;;

  --check)
    # One-shot version of --wait: no internal sleep, no retry. Meant to be
    # called once per scheduled wakeup in a cloud/remote session instead of
    # blocking the session on a Bash sleep loop.
    if [ "$UNSUPERVISED" != "true" ] || [ -z "$THRESHOLD" ]; then
      echo "RESUME_OK (no usage threshold configured)"; rm -f "$WAIT_MARKER"; exit 0
    fi
    RESUME_AT=$(( THRESHOLD - RESUME_MARGIN )); [ "$RESUME_AT" -lt 5 ] && RESUME_AT=5
    if ! get_usage; then
      echo "RESUME_OK (usage unknown — failing open)"; rm -f "$WAIT_MARKER"; exit 0
    fi
    if [ "$(max_pct)" -le "$RESUME_AT" ]; then
      echo "RESUME_OK — $(usage_line)"; rm -f "$WAIT_MARKER"; exit 0
    fi
    touch "$WAIT_MARKER"
    echo "WAITING — usage above resume level (${RESUME_AT}%). $(usage_line)"
    echo "Schedule another wakeup and check again later — do not loop on this command."
    exit 0
    ;;

  *)  # hook mode (PostToolUse)
    cat > /dev/null 2>&1 || true   # drain stdin

    if [ "$UNSUPERVISED" = "true" ]; then
      [ -z "$THRESHOLD" ] && exit 0
      # already pausing? stay silent so the wait loop isn't interrupted
      if [ -f "$WAIT_MARKER" ]; then
        AGE=$(( $(now) - $(mtime "$WAIT_MARKER") ))
        [ "$AGE" -lt 600 ] && exit 0
        rm -f "$WAIT_MARKER"
      fi
      get_usage || exit 0   # fail open
      if [ "$(max_pct)" -ge "$THRESHOLD" ]; then
        touch "$WAIT_MARKER"
        {
          echo "USAGE THRESHOLD REACHED (${THRESHOLD}%): $(usage_line)"
          echo "Pause now: 1) finish/commit only the current atomic step, 2) update the checkpoint in .claude/memory/context.md,"
          echo "3) then follow the CLAUDE.md 'Session Behavior' pause procedure for this session type:"
          echo "   loop-mode.marker present -> stop the session; a schedule-a-future-message tool available (cloud/remote session) -> usage-guard.sh --check once, then schedule a wakeup instead of polling; otherwise -> usage-guard.sh --wait repeatedly until RESUME_OK."
          echo "Do not start new subtasks before RESUME_OK."
        } >&2
        exit 2
      fi
      exit 0
    fi

    # Supervised mode: offer to switch to unsupervised when usage is high.
    # Uses threshold from settings.md if set, otherwise defaults to 80%.
    SUPERVISED_THRESHOLD=${THRESHOLD:-80}

    # If the offer was already made this crossing, stay silent.
    # Clear the marker if usage has recovered so the offer can fire again later.
    if [ -f "$OFFER_MARKER" ]; then
      if get_usage && [ "$(max_pct)" -le $(( SUPERVISED_THRESHOLD - RESUME_MARGIN )) ]; then
        rm -f "$OFFER_MARKER"   # recovered — allow re-offer on next crossing
      fi
      exit 0
    fi

    get_usage || exit 0   # fail open
    if [ "$(max_pct)" -ge "$SUPERVISED_THRESHOLD" ]; then
      touch "$OFFER_MARKER"
      PCT=$(max_pct)
      {
        echo "SUPERVISED_USAGE_ALERT (${PCT}%): $(usage_line)"
        echo "Session usage has reached ${SUPERVISED_THRESHOLD}%. Use AskUserQuestion to offer the user a switch to unsupervised mode:"
        echo "  Question: 'Session usage is at ${PCT}%. Switch to unsupervised mode so auto-resume is available if this session is interrupted?'"
        echo "  Options: [Yes — unsupervised on 80 / Yes — let me pick the threshold / No — continue supervised]"
        echo "If the user agrees, run the /unsupervised skill with their chosen threshold (default 80)."
        echo "If the user declines, continue normally. This alert won't repeat until usage drops below $((SUPERVISED_THRESHOLD - RESUME_MARGIN))% and rises again."
      } >&2
      exit 2
    fi
    exit 0
    ;;
esac
