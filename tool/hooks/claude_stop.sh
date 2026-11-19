#!/usr/bin/env bash
# Claude Code Stop hook (.claude/settings.json): runs tool/check_tokens.sh so
# an agent sees a token violation before it finishes. Exit 2 blocks the stop
# and hands stderr to the agent. If the agent was already sent back once
# (stop_hook_active), let it stop, so a check it can't fix doesn't loop.
input=$(cat)
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi
"$(dirname "$0")/../check_tokens.sh" >&2 || exit 2
