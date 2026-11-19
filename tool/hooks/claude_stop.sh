#!/usr/bin/env bash
# Claude Code Stop hook (.claude/settings.json): runs tool/check_tokens.sh so
# an agent sees a token violation before it finishes. Exit 2 blocks the stop
# and hands stderr to the agent. If the agent was already sent back once
# (stop_hook_active), let it stop, so a check it can't fix doesn't loop.
#
# It checks the checkout the hook runs in (git rev-parse --show-toplevel), so
# a session in a worktree checks that worktree, not $CLAUDE_PROJECT_DIR.
input=$(cat)
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
check="$root/tool/check_tokens.sh"
[ -x "$check" ] || exit 0   # a branch from before the check existed
"$check" >&2 || exit 2
