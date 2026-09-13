#!/usr/bin/env bash
# hallucination-guard-hook.sh — PostToolUse hook
# Detects consecutive tool failures (agent referring to non-existent files/commands)
# and triggers an auto-compact recommendation when threshold is exceeded.

set -euo pipefail

COUNTER_FILE="${TMPDIR:-/tmp}/.claude_failure_count"
THRESHOLD=3

INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" \
  2>/dev/null || echo "")

# Only monitor tools that can reveal hallucination
case "$TOOL" in
  Read|Edit|Write|Bash) ;;
  *) exit 0 ;;
esac

# Extract tool response / error
RESPONSE=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); r=d.get('tool_response',{}); print(r.get('output','') if isinstance(r,dict) else str(r))" \
  2>/dev/null || echo "")

# Detect failure signals
IS_FAILURE=0

# File not found (Read, Edit targeting non-existent file)
if echo "$RESPONSE" | grep -qiE '(does not exist|no such file|not found|cannot find|file not found|ENOENT|cannot open)'; then
  IS_FAILURE=1
fi

# Command not found (Bash inventing tools/scripts)
if echo "$RESPONSE" | grep -qiE '(command not found|not recognized|is not recognized|No command|unknown command)'; then
  IS_FAILURE=1
fi

# Edit tool reporting old_string not found (agent invented code that doesn't exist)
if echo "$RESPONSE" | grep -qiE '(String to replace not found|old_string not found|pattern not found)'; then
  IS_FAILURE=1
fi

# Permission denied or unreadable — not a hallucination, skip
if echo "$RESPONSE" | grep -qiE '(permission denied|access denied)'; then
  exit 0
fi

if [[ $IS_FAILURE -eq 1 ]]; then
  # Increment failure counter
  COUNT=1
  if [[ -f "$COUNTER_FILE" ]]; then
    COUNT=$(( $(cat "$COUNTER_FILE" 2>/dev/null || echo 0) + 1 ))
  fi
  echo "$COUNT" > "$COUNTER_FILE"

  if [[ $COUNT -ge $THRESHOLD ]]; then
    # Reset counter so we don't spam
    echo "0" > "$COUNTER_FILE"
    # Output a message Claude will see — triggers compact
    cat << 'COMPACT_MSG'
⚠️  CONTEXT MANAGER: Auto-compact triggered.

The agent has encountered 3 consecutive tool failures, which typically indicates
context drift or hallucination (referencing files/code that do not exist).

Running /compact now to reset context while preserving key information.
Please re-read FILE_MAP.md and CONTEXT.md before continuing.

/compact
COMPACT_MSG
  fi
else
  # Successful tool call — reset failure counter
  echo "0" > "$COUNTER_FILE"
fi

exit 0
