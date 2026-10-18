#!/usr/bin/env python3
"""Initialize Context Manager files and host-specific project instructions."""

from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import date
from pathlib import Path


CODING_RULES = """# Coding Rules

These rules apply to all code written in this project. They are non-negotiable.

## No unnecessary comments
Only add a comment when logic is genuinely non-obvious. Never describe what code does — only why, and only when surprising. Do not add comments to code you did not change.

## No docstrings unless asked
Do not add docstrings, JSDoc blocks, or inline type annotations to existing functions unless the user explicitly requests them.

## No speculative additions
Do not add features, error handling, validation, fallbacks, or logging for scenarios that do not exist in the current task. Do not design for hypothetical future requirements.

## No collateral refactoring
Fix only what was asked. Do not clean up surrounding code, rename variables for style, or reformat lines you did not change.

## No backwards-compat debris
If code is unused after your change, delete it. Do not add removed, deprecated, or re-export shims unless the user asks.

## Minimal diffs
The correct amount of code is the minimum needed to complete the task. When in doubt, write less.
"""

CONTEXT_TEMPLATE = """---
project: {project}
last_updated: {today}
---

## Goals
- 

## Architecture
- 

## Active Tasks
- 

## Recent Decisions
- 

## Known Issues / Blockers
- 

## Agent Handoff Notes
- 
"""

CODEX_BLOCK = """<!-- context-manager:start -->
## Context Manager
Use the `context-manager` skill for context initialization, handoff, or project-memory updates. For tasks needing project history or file discovery, read only the relevant `.claude/` context files: `CODING_RULES.md`, `CONTEXT.md`, `FILE_MAP.md`, and `PROJECT_MEMORY.md`. Do not read all of them for trivial edits. Regenerate `FILE_MAP.md` after creates, deletes, renames, or broad refactors.
<!-- context-manager:end -->
"""

CLAUDE_BLOCK = """<!-- context-manager:start -->
@.claude/CODING_RULES.md
@.claude/CONTEXT.md
@.claude/FILE_MAP.md
@.claude/PROJECT_MEMORY.md
<!-- context-manager:end -->
"""


def replace_managed_block(path: Path, block: str) -> None:
    start = "<!-- context-manager:start -->"
    end = "<!-- context-manager:end -->"
    current = path.read_text(encoding="utf-8") if path.exists() else ""
    if start in current and end in current:
        before, remainder = current.split(start, 1)
        _, after = remainder.split(end, 1)
        content = before.rstrip() + "\n\n" + block.rstrip() + "\n" + after.lstrip()
    else:
        content = current.rstrip() + ("\n\n" if current.strip() else "") + block
    path.write_text(content, encoding="utf-8")


def host_file(root: Path, host: str) -> tuple[Path, str | None]:
    if host == "codex":
        return root / "AGENTS.md", CODEX_BLOCK
    if host == "claude":
        return root / "CLAUDE.md", CLAUDE_BLOCK
    if host == "kimi":
        return root / "AGENTS.md", CLAUDE_BLOCK
    return root, None


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize Context Manager in a project")
    parser.add_argument("root", nargs="?", default=".", help="Project root directory")
    parser.add_argument("--host", choices=("codex", "claude", "kimi", "none"), default="codex")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    script_dir = Path(__file__).resolve().parent
    context_dir = root / ".claude"
    context_dir.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        [sys.executable, str(script_dir / "generate-map.py"), str(root), "--output", str(context_dir / "FILE_MAP.md")],
        check=True,
    )
    subprocess.run([sys.executable, str(script_dir / "init-memory.py"), str(root)], check=True)

    context_file = context_dir / "CONTEXT.md"
    if not context_file.exists():
        context_file.write_text(
            CONTEXT_TEMPLATE.format(project=root.name, today=date.today().isoformat()),
            encoding="utf-8",
        )

    rules_file = context_dir / "CODING_RULES.md"
    if not rules_file.exists():
        rules_file.write_text(CODING_RULES, encoding="utf-8")

    instruction_file, block = host_file(root, args.host)
    if block is not None:
        replace_managed_block(instruction_file, block)

    print(f"Context Manager initialized: {context_dir}")
    if block is not None:
        print(f"Updated host instructions: {instruction_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
