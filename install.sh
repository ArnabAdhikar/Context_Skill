#!/usr/bin/env bash
# Install the Context Manager skill for Claude Code, Codex, or both.
# Usage: bash install.sh [--claude|--codex|--all]

set -euo pipefail

TARGET="claude"
case "${1:-}" in
  ""|--claude) TARGET="claude" ;;
  --codex) TARGET="codex" ;;
  --all) TARGET="all" ;;
  -h|--help)
    printf 'Usage: bash install.sh [--claude|--codex|--all]\n'
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\nUsage: bash install.sh [--claude|--codex|--all]\n' "$1" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

install_codex() {
  local skill_dir="$CODEX_DIR/skills/context-manager"
  mkdir -p "$skill_dir/scripts"
  cp "$SCRIPT_DIR/context-manager.md" "$skill_dir/SKILL.md"
  cp "$SCRIPT_DIR/scripts/generate-map.py" "$skill_dir/scripts/generate-map.py"
  cp "$SCRIPT_DIR/scripts/init-memory.py" "$skill_dir/scripts/init-memory.py"
  cp "$SCRIPT_DIR/scripts/init-context.py" "$skill_dir/scripts/init-context.py"
  chmod +x "$skill_dir/scripts/"*.py

  printf '  ✓ Codex skill: %s/SKILL.md\n' "$skill_dir"
  printf '  ✓ Codex scripts: generate-map.py, init-memory.py, init-context.py\n'
}

register_claude_hook() {
  local type="$1"
  local command="$2"
  local name="$3"
  local settings_file="$CLAUDE_DIR/settings.json"

  python3 - "$type" "$command" "$name" "$settings_file" <<'PYEOF'
import json
import sys

hook_type, command, name, path = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as file:
        settings = json.load(file)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

bucket = settings.setdefault("hooks", {}).setdefault(hook_type, [])
if not any(name in json.dumps(entry) for entry in bucket):
    bucket.append({"hooks": [{"type": "command", "command": command}]})

with open(path, "w", encoding="utf-8") as file:
    json.dump(settings, file, indent=2)
    file.write("\n")
PYEOF
}

install_claude() {
  local skills_dir="$CLAUDE_DIR/skills"
  local hooks_dir="$CLAUDE_DIR/hooks"
  local scripts_dir="$CLAUDE_DIR/scripts"
  local settings_file="$CLAUDE_DIR/settings.json"
  mkdir -p "$skills_dir" "$hooks_dir" "$scripts_dir"

  cp "$SCRIPT_DIR/context-manager.md" "$skills_dir/context-manager.md"
  cp "$SCRIPT_DIR/scripts/generate-map.py" "$scripts_dir/generate-map.py"
  cp "$SCRIPT_DIR/scripts/init-memory.py" "$scripts_dir/init-memory.py"
  cp "$SCRIPT_DIR/scripts/init-context.py" "$scripts_dir/init-context.py"
  printf '  ✓ Claude skill and scripts installed\n'

  for hook in context-save-hook file-map-hook hallucination-guard-hook; do
    cp "$SCRIPT_DIR/hooks/${hook}.sh" "$hooks_dir/${hook}.sh"
    chmod +x "$hooks_dir/${hook}.sh"
  done
  register_claude_hook "Stop" "bash $hooks_dir/context-save-hook.sh" "context-save-hook"
  register_claude_hook "PostToolUse" "bash $hooks_dir/file-map-hook.sh" "file-map-hook"
  register_claude_hook "PostToolUse" "bash $hooks_dir/hallucination-guard-hook.sh" "hallucination-guard-hook"
  printf '  ✓ Claude hooks registered\n'

  python3 - "$settings_file" <<'PYEOF'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as file:
        settings = json.load(file)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("env", {}).update({
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
    "CLAUDE_CODE_SUBAGENT_MODEL_FORCE": "1",
})
with open(path, "w", encoding="utf-8") as file:
    json.dump(settings, file, indent=2)
    file.write("\n")
PYEOF
  printf '  ✓ Claude subagents pinned to Haiku\n'
}

printf 'Installing Context Manager (%s)...\n' "$TARGET"
if [[ "$TARGET" == "codex" || "$TARGET" == "all" ]]; then
  install_codex
fi
if [[ "$TARGET" == "claude" || "$TARGET" == "all" ]]; then
  install_claude
fi

printf '\nDone.\n'
if [[ "$TARGET" == "codex" || "$TARGET" == "all" ]]; then
  printf 'Codex: restart Codex, then ask it to use $context-manager to initialize a project.\n'
  printf 'Direct initialization: python3 "%s/skills/context-manager/scripts/init-context.py" <project-root> --host codex\n' "$CODEX_DIR"
fi
if [[ "$TARGET" == "claude" || "$TARGET" == "all" ]]; then
  printf 'Claude Code: open a project and run /ctx init.\n'
fi