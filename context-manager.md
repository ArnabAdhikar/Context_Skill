# Context Manager Skill

**Trigger**: `/ctx` or `/context`

## What this skill does

Manages a `.claude/` knowledge base inside your project:

| File | Purpose | Updated by |
|---|---|---|
| `CONTEXT.md` | Goals, decisions, tasks, blockers | `/ctx save` |
| `FILE_MAP.md` | Full annotated file tree | Auto: every file change |
| `PROJECT_MEMORY.md` | Index to project memory | Auto: `/ctx init` |
| `MEMORY/stack.md` | Tech stack, frameworks, deps | Auto: `/ctx init` |
| `MEMORY/decisions.md` | Architectural decisions + reasons | `/ctx mem` |
| `MEMORY/apis.md` | External services, env vars | `/ctx mem` |
| `MEMORY/patterns.md` | Code conventions, anti-patterns | `/ctx mem` |
| `CODING_RULES.md` | Non-negotiable code quality rules | Set once on init |

All files load automatically every session via CLAUDE.md `@` includes.

---

## Commands

### `/ctx` or `/ctx status`
Summarize what is known: read CONTEXT.md, FILE_MAP.md, and PROJECT_MEMORY.md. Print a clean digest. If none exist, suggest `/ctx init`.

### `/ctx init`

Run these steps in order:

1. **Generate file map**
   ```
   python3 ~/.claude/scripts/generate-map.py <project-root> --output .claude/FILE_MAP.md
   ```

2. **Initialize project memory**
   ```
   python3 ~/.claude/scripts/init-memory.py <project-root>
   ```
   This scans package.json / Cargo.toml / go.mod / pyproject.toml / .env.example and pre-populates:
   - `.claude/MEMORY/stack.md` — detected runtime, frameworks, deps
   - `.claude/MEMORY/decisions.md` — blank template
   - `.claude/MEMORY/apis.md` — env vars extracted from .env.example
   - `.claude/MEMORY/patterns.md` — blank template
   - `.claude/PROJECT_MEMORY.md` — index file

3. **Create CONTEXT.md** using the template below. Infer project name, goals, and stack from README, package.json, etc.

4. **Write CODING_RULES.md** — create `.claude/CODING_RULES.md` with the exact content from the Coding Rules section at the bottom of this file.

5. **Wire CLAUDE.md** — check if CLAUDE.md exists in project root:
   - If yes: append missing lines only
   - If no: create it
   
   The final CLAUDE.md must contain (in this order):
   ```
   @.claude/CODING_RULES.md
   @.claude/CONTEXT.md
   @.claude/FILE_MAP.md
   @.claude/PROJECT_MEMORY.md
   ```

6. Confirm: "Context Manager initialized. Project memory, file map, and coding rules are active."

### `/ctx save`
Update `.claude/CONTEXT.md` based on the current session:
- **Strip**: raw terminal output, stack traces, test results, diff hunks, compiler errors (unless they explain a decision), repeated errors
- **Keep**: file paths created/deleted/renamed, why approaches were chosen or rejected, what is currently in-progress or broken, external APIs or env vars encountered, current branch or PR if mentioned
- Update `last_updated`. Preserve all still-relevant sections. Remove stale ones.
- Confirm: "Context saved — [one-line summary]."

### `/ctx map`
Regenerate `.claude/FILE_MAP.md`:
```
python3 ~/.claude/scripts/generate-map.py <project-root> --output .claude/FILE_MAP.md
```
Confirm: "File map updated."

### `/ctx mem [note]`
Add a note to project memory. Route it to the right file:
- Tech stack / dependency change → `MEMORY/stack.md`
- Architectural decision → `MEMORY/decisions.md` (format: decision — **Why:** reason)
- New API / service / env var → `MEMORY/apis.md`
- Code pattern or anti-pattern → `MEMORY/patterns.md`

If no note is given, show a summary of all memory files.

### `/ctx update [section]`
Update a specific section of CONTEXT.md. Valid: `goals`, `decisions`, `architecture`, `tasks`, `notes`. Add section if missing; preserve all others.

### `/ctx share`
Output CONTEXT.md + FILE_MAP.md + PROJECT_MEMORY.md as one markdown block for pasting into any other agent. Prepend: "Paste this to resume context:"

### `/ctx reset`
Confirm with user, then wipe CONTEXT.md to empty template and regenerate FILE_MAP.md and project memory. Do not touch CLAUDE.md or CODING_RULES.md.

### `/ctx filter`
Extract signal from the last assistant turn: decisions made, files changed, tasks completed or blocked. Output as bullets for `/ctx save`.

---

## File Map — Auto-Update

`FILE_MAP.md` is regenerated silently in the background by the `file-map-hook` after every `Write`, `Edit`, or file-creating `Bash` call. No user action needed.

Use `/ctx map` only after a large refactor or if the hook missed something.

---

## Hallucination Auto-Compact

The `hallucination-guard-hook` monitors every tool call. When it detects **3 consecutive tool failures** (file not found, command not found, old_string not found), it outputs a `/compact` signal.

Failure types that count:
- `Read` or `Edit` targeting a file that does not exist
- `Bash` running a command that does not exist
- `Edit` with `old_string` that is not in the file (agent invented code)

A successful tool call resets the counter.

When `/compact` fires automatically: re-read `FILE_MAP.md` and `CONTEXT.md` before answering the next query. Do not guess file paths — always verify against the map.

---

## CONTEXT.md Template

```markdown
---
project: [infer from directory name or package.json/Cargo.toml/etc]
last_updated: [today's date]
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
```

---

## Coding Rules

When writing `.claude/CODING_RULES.md`, use this exact content:

```markdown
# Coding Rules

These rules apply to all code written in this project. They are non-negotiable.

## No unnecessary comments
Only add a comment when logic is genuinely non-obvious. Never describe *what* the code does — only *why*, and only when surprising. Do not add comments to code you did not change.

## No docstrings unless asked
Do not add docstrings, JSDoc blocks, or inline type annotations to existing functions unless the user explicitly requests them.

## No speculative additions
Do not add features, error handling, validation, fallbacks, or logging for scenarios that do not exist in the current task. Do not design for hypothetical future requirements.

## No collateral refactoring
Fix only what was asked. Do not clean up surrounding code, rename variables for style, or reformat lines you did not change.

## No backwards-compat debris
If code is unused after your change, delete it. Do not add `// removed`, `// deprecated`, or re-export shims unless the user asks.

## Minimal diffs
The correct amount of code is the minimum needed to complete the task. When in doubt, write less.
```

---

## Cross-Agent Usage

**Claude Code** — everything auto-loads via CLAUDE.md `@` includes.

**Cursor / Copilot / other agents** — run `/ctx share`, paste the output at the start of the chat.

**New Claude session with no CLAUDE.md** — same as above.

---

## For Exploration Agents

When `FILE_MAP.md` is in context:
1. Read it to locate files — skip Glob and `find` commands
2. Use Grep only to search file *contents*, not locations
3. Fall back to filesystem tools only if the map is stale or a directory is truncated

---

## Auto-Save Reminder

At the end of any session where significant work happened, say:
> "Run `/ctx save` to update project context before switching sessions."

Trigger when: 3+ files changed, a major decision made, or the user says they're done.
