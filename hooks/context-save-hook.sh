#!/usr/bin/env bash
# context-save-hook.sh
# Claude Code Stop hook — reminds Claude to save context at end of session.
# Place in: ~/.claude/hooks/context-save-hook.sh
# Register in: ~/.claude/settings.json under hooks.Stop

set -euo pipefail

# Read the hook event JSON from stdin
INPUT=$(cat)

# Only act on Stop events
EVENT_TYPE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null || echo "")

if [[ "$EVENT_TYPE" != "Stop" ]]; then
  exit 0
fi

# Check if we're inside a git repo (i.e., a real project)
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONTEXT_FILE="$PROJECT_ROOT/.claude/CONTEXT.md"

# Output a reminder message that Claude will see before stopping
# This uses the hook's stdout-as-feedback mechanism
if [[ -f "$CONTEXT_FILE" ]]; then
  LAST_UPDATED=$(grep 'last_updated:' "$CONTEXT_FILE" 2>/dev/null | head -1 | sed 's/.*last_updated: //' || echo "unknown")
  TODAY=$(date +%Y-%m-%d)
  if [[ "$LAST_UPDATED" != "$TODAY" ]]; then
    echo "CONTEXT REMINDER: Project context was last updated on $LAST_UPDATED. Consider running \`/ctx save\` to capture today's work before ending the session."
  fi
else
  echo "CONTEXT REMINDER: No .claude/CONTEXT.md found in this project. Run \`/ctx init\` to start tracking context."
fi

exit 0
