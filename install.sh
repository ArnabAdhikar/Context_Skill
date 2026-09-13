#!/usr/bin/env bash
# install.sh — Install the Context Manager skill for Claude Code
# Usage: bash install.sh

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Context Manager..."

mkdir -p "$SKILLS_DIR" "$HOOKS_DIR" "$SCRIPTS_DIR"

# ── Files ────────────────────────────────────────────────────────────────────
cp "$SCRIPT_DIR/context-manager.md"              "$SKILLS_DIR/context-manager.md"
echo "  ✓ Skill:   $SKILLS_DIR/context-manager.md"

cp "$SCRIPT_DIR/scripts/generate-map.py"         "$SCRIPTS_DIR/generate-map.py"
cp "$SCRIPT_DIR/scripts/init-memory.py"          "$SCRIPTS_DIR/init-memory.py"
echo "  ✓ Scripts: generate-map.py, init-memory.py"

for hook in context-save-hook file-map-hook hallucination-guard-hook; do
  cp "$SCRIPT_DIR/hooks/${hook}.sh" "$HOOKS_DIR/${hook}.sh"
  chmod +x "$HOOKS_DIR/${hook}.sh"
done
echo "  ✓ Hooks:   context-save-hook, file-map-hook, hallucination-guard-hook"

# ── Register hooks in settings.json ─────────────────────────────────────────
register_hook() {
  local TYPE="$1"
  local CMD="$2"
  local NAME="$3"

  if [[ -f "$SETTINGS_FILE" ]] && grep -q "$NAME" "$SETTINGS_FILE" 2>/dev/null; then
    echo "  ✓ Already registered: $TYPE → $NAME"
    return
  fi

  python3 - "$TYPE" "$CMD" "$NAME" "$SETTINGS_FILE" << 'PYEOF'
import json, sys

hook_type, cmd, name, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

try:
    with open(path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault("hooks", {})
bucket = hooks.setdefault(hook_type, [])

new_entry = {"hooks": [{"type": "command", "command": cmd}]}
if not any(name in str(h) for h in bucket):
    bucket.append(new_entry)

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
  echo "  ✓ Registered: $TYPE → $NAME"
}

register_hook "Stop"        "bash $HOOKS_DIR/context-save-hook.sh"      "context-save-hook"
register_hook "PostToolUse" "bash $HOOKS_DIR/file-map-hook.sh"          "file-map-hook"
register_hook "PostToolUse" "bash $HOOKS_DIR/hallucination-guard-hook.sh" "hallucination-guard-hook"

# ── Pin subagents to cheapest model (Haiku) globally ─────────────────────────
python3 - "$SETTINGS_FILE" << 'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

env = settings.setdefault("env", {})
env["CLAUDE_CODE_SUBAGENT_MODEL"] = "haiku"
env["CLAUDE_CODE_SUBAGENT_MODEL_FORCE"] = "1"

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
echo "  ✓ Subagents: pinned to claude-haiku (cheapest model, forced globally)"

echo ""
echo "Done."
echo ""
echo "Quick start:"
echo "  1. Open any project in Claude Code"
echo "  2. Run: /ctx init"
echo "     → Generates FILE_MAP.md (full annotated file tree)"
echo "     → Creates .claude/MEMORY/ (stack, decisions, APIs, patterns)"
echo "     → Injects CODING_RULES.md (no useless comments, no speculative code)"
echo "     → Wires everything into CLAUDE.md for auto-load"
echo "  3. Run /ctx save before ending each session"
echo "  4. Run /ctx share to hand off to another agent"
