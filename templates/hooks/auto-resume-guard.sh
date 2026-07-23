#!/usr/bin/env bash
# UserPromptSubmit hook: keep the recovery heartbeat armed whenever auto_resume is on — for ANY
# work, including free chat outside a skill. A limit-stalled cloud session doesn't restart itself;
# the heartbeat is what pokes it back to life, so it must be armed BEFORE the limit hits.
#
# The CHECK is fully script-side and cheap (two greps + one env test). A hook can't create the
# Routine itself — trigger creation is MCP-only, agent-only — so when arming is actually needed
# this emits a single one-line nudge for the agent to arm it. Crucially it does so ONLY while the
# heartbeat is not yet armed: once settings.md records `recovery_trigger:`, this stays completely
# silent for the rest of the session, so there is NO per-prompt overhead in steady state.
set -uo pipefail
cat >/dev/null 2>&1 || true   # drain stdin (prompt JSON) — content not needed

SETTINGS="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/settings.md"
[ -f "$SETTINGS" ] || exit 0
grep -qi '^auto_resume:[[:space:]]*true' "$SETTINGS" 2>/dev/null || exit 0   # auto_resume off → nothing to do
[ -n "${CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE:-}" ] || exit 0                   # cloud/remote only (heartbeat is a cloud Routine)
grep -qi '^recovery_trigger:' "$SETTINGS" 2>/dev/null && exit 0              # already armed → silent, zero cost

echo "[auto-resume] auto_resume is on and no recovery heartbeat is armed. Arm it now — one idempotent create_trigger, see /auto-resume — so if this session stalls at the limit it can wake itself. Do it silently; don't mention it in your reply."
exit 0
