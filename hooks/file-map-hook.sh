#!/usr/bin/env bash
# file-map-hook.sh — PostToolUse hook
# Regenerates .claude/FILE_MAP.md after any file-writing tool call.
# Registered under hooks.PostToolUse in settings.json.

set -euo pipefail

INPUT=$(cat)

# Extract tool name from hook JSON
TOOL=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" \
  2>/dev/null || echo "")

# Only regenerate after tools that change the file system
case "$TOOL" in
  Write|Edit|Bash) ;;
  *) exit 0 ;;
esac

# For Bash tool, skip if the command is a pure read (grep/cat/ls/git log etc.)
if [[ "$TOOL" == "Bash" ]]; then
  CMD=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" \
    2>/dev/null || echo "")
  # If command doesn't contain write-like keywords, skip
  if ! echo "$CMD" | grep -qE '(mkdir|touch|mv|cp|rm |rmdir|>|>>|tee |install |npm |yarn |pip |cargo |go get|git (add|commit|checkout|merge|rebase|reset))'; then
    exit 0
  fi
fi

# Find project root (git-aware)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONTEXT_FILE="$PROJECT_ROOT/.claude/CONTEXT.md"

# Only run if this project has been init'd
if [[ ! -f "$CONTEXT_FILE" ]]; then
  exit 0
fi

SCRIPT="$HOME/.claude/scripts/generate-map.py"
MAP_FILE="$PROJECT_ROOT/.claude/FILE_MAP.md"

if [[ ! -f "$SCRIPT" ]]; then
  exit 0
fi

# Regenerate map (silent — don't pollute tool output)
python3 "$SCRIPT" "$PROJECT_ROOT" --output "$MAP_FILE" 2>/dev/null &

exit 0
