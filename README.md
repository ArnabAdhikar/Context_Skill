# Context Manager — Claude Code Skill

Persistent, noise-filtered project context + live file map + project memory that travels with your codebase, auto-loads every session, enforces clean code, and keeps agents from hallucinating.

---

## Benchmark Results

> Tested against a realistic 18-file TypeScript/Node.js project (Express + Prisma + Jest).
> Task: answer three questions — "Where is the DB client? What env vars are needed? What test framework is used?"

### Tool Calls: Before vs After

```
WITHOUT skill (blind exploration)
─────────────────────────────────────────────────────────────────
Glob "**/*.ts"          ████████████████████████  ~150 tokens
Read client.ts          ██████████████████        ~300 tokens
Glob "**/*.json"        ████████████████████████  ~150 tokens
Read package.json       ██████████████████████    ~350 tokens
Read .env.example       ████████████              ~100 tokens
─────────────────────────────────────────────────────────────────
Total                   5 tool calls              ~1,050 tokens

WITH skill (FILE_MAP.md pre-loaded)
─────────────────────────────────────────────────────────────────
Read FILE_MAP.md        ████                      ~250 tokens
─────────────────────────────────────────────────────────────────
Total                   1 tool call               ~250 tokens

Reduction               ████████████████░░░░      80% fewer calls
                        ██████████████████░░      76% fewer tokens
```

### Subagent Cost: Before vs After

```
Model           Price/1M tokens    Typical exploration    Monthly (50 sessions)
──────────────────────────────────────────────────────────────────────────────
Sonnet (before) $3.00              $0.0158               $0.79
Haiku  (after)  $1.00              $0.0053               $0.26
──────────────────────────────────────────────────────────────────────────────
Savings                            $0.0105 per task       $0.53/month  (-67%)
```

```
Cost per exploration task
─────────────────────────────────
Before  ████████████████  $0.0158
After   █████             $0.0053
        ──────────────────────────
        67% cheaper  ·  Haiku forced globally
```

### Session Continuity: Before vs After

```
                     WITHOUT skill    WITH skill
─────────────────────────────────────────────────────
New session setup    Re-explore repo  Instant (auto-loaded)
Context carried over None             Goals + decisions + tasks
File discovery       Every session    Zero (FILE_MAP.md)
Cross-agent handoff  Manual paste     /ctx share (one command)
Hallucination rate   Unchecked        Auto-compact at 3 failures
Code noise           Comments + docs  Blocked by CODING_RULES.md
```

### Init Performance (measured)

```
Operation                  Time      Output
───────────────────────────────────────────────────────────
generate-map.py            310 ms    38-line annotated tree
init-memory.py             231 ms    5 memory files
Total /ctx init overhead   ~550 ms   One-time per project
```

---

## Test Results (End-to-End)

Tested 2026-09-13 against ctx_test_project (18 source files, Node.js/TS).

```
Component                                        Result
────────────────────────────────────────────────────────────────────────
generate-map.py — runs without error             PASS
FILE_MAP.md — correct annotated tree             PASS  (38 lines, 25 entries)
init-memory.py — runs without error              PASS
stack.md — detects Node.js runtime               PASS
stack.md — detects frameworks                    PASS  (Express, Prisma ORM, Jest)
apis.md — captures all 4 env vars                PASS  (DB_URL, JWT_SECRET, API_KEY, PORT)
PROJECT_MEMORY.md — index correct                PASS
hallucination-guard — fires on 3rd failure       PASS  (outputs /compact + explanation)
hallucination-guard — resets on success          PASS  (counter → 0)
file-map-hook — skips non-init projects          PASS  (silent exit 0)
file-map-hook — regenerates after file write     PASS  (fixed: ArgumentList array for space-safe paths)
CLAUDE.md — contains all 4 @ includes            PASS
settings.json — valid JSON                       PASS  (fixed: proper \\ escaping)
settings.json — CLAUDE_CODE_SUBAGENT_MODEL=haiku PASS
settings.json — CLAUDE_CODE_SUBAGENT_MODEL_FORCE PASS
────────────────────────────────────────────────────────────────────────
15/15 PASS   0 FAIL
```

**Bugs found and fixed during testing:**
1. `file-map-hook.ps1` — `Start-Process -ArgumentList` used a single interpolated string, breaking when project paths contained spaces (e.g. `OneDrive\Desktop\...`). Fixed: switched to array form `@($script, $root, '--output', $map)`.
2. `settings.json` — bash heredoc wrote single backslashes (`\.`), which are invalid JSON escape sequences. Fixed: settings now written via Python `json.dumps()` which produces correct `\\` escaping.

---

## What Gets Installed

```
~/.claude/
├── settings.json               ← env: haiku model forced for all subagents
│                                  hooks: Stop + PostToolUse (×2) registered
├── skills/
│   └── context-manager.md      ← /ctx skill (all commands)
├── scripts/
│   ├── generate-map.py         ← gitignore-aware tree scanner with file annotations
│   └── init-memory.py          ← project memory bootstrapper (detects stack, env vars)
└── hooks/
    ├── context-save-hook.ps1   ← Stop hook: reminds to /ctx save if context is stale
    ├── file-map-hook.ps1       ← PostToolUse: regenerates FILE_MAP.md on file changes
    └── hallucination-guard-hook.ps1  ← PostToolUse: auto /compact after 3 failures
```

Per-project (created by `/ctx init`):
```
.claude/
├── CONTEXT.md              ← Goals, decisions, tasks, blockers (human-curated)
├── FILE_MAP.md             ← Annotated file tree (auto-updated on every file change)
├── PROJECT_MEMORY.md       ← Memory index (auto-loaded via CLAUDE.md)
├── CODING_RULES.md         ← No useless comments, no speculative code (enforced)
└── MEMORY/
    ├── stack.md            ← Runtime, frameworks, deps (auto-detected from config)
    ├── decisions.md        ← Architectural decisions + reasons
    ├── apis.md             ← External services, env vars (auto-detected from .env.example)
    └── patterns.md         ← Code conventions and anti-patterns
CLAUDE.md                   ← @-includes all 4 .claude/ files (auto-loaded every session)
```

---

## Install

**macOS / Linux**
```bash
git clone <this-repo> context-manager
cd context-manager
bash install.sh
```

**Windows (PowerShell)**
```powershell
git clone <this-repo> context-manager
cd context-manager
.\install.ps1
```

---

## Usage

### Initialize a project
```
/ctx init
```
Runs in ~550ms. Creates the full `.claude/` structure, detects stack and env vars, wires CLAUDE.md. Commit `.claude/` alongside your code — context travels with the repo.

### Commands

| Command | What it does |
|---|---|
| `/ctx` | Show context digest |
| `/ctx init` | Full init: map + memory + coding rules + CLAUDE.md wiring |
| `/ctx save` | Update CONTEXT.md from current session (noise-filtered) |
| `/ctx map` | Regenerate FILE_MAP.md manually |
| `/ctx mem [note]` | Add a note to project memory |
| `/ctx update [section]` | Update one CONTEXT.md section |
| `/ctx share` | Output everything for pasting into another agent |
| `/ctx filter` | Extract signal from last response |
| `/ctx reset` | Wipe context, regenerate map and memory |

---

## How Each Feature Works

### FILE_MAP.md — Auto-updating file tree

Generated by `generate-map.py`. Respects `.gitignore`. Skips build dirs, binaries, images. Annotates files from their first comment line, `package.json` description, or known filename patterns.

Regenerated **automatically in the background** after every `Write`, `Edit`, or file-creating `Bash` call via the `PostToolUse` hook.

Example output:
```
my-app/
├── src/
│   ├── index.ts  ← Application entry point
│   ├── api/
│   │   ├── router.ts  ← Express router — mounts /users, /posts, /auth
│   │   └── middleware.ts  ← JWT auth middleware
│   └── db/
│       ├── client.ts  ← Prisma database client
│       └── schema.prisma  ← Prisma database schema
├── tests/
│   └── api.test.ts  ← Jest integration tests
├── package.json  ← "my-app" — REST API service
└── .claude/
    ├── CONTEXT.md  ← Auto-managed project context
    └── FILE_MAP.md  ← Auto-generated file map
```

Exploration agents read this instead of running Glob/find → **80% fewer tool calls, 76% fewer tokens.**

### Project Memory — Auto-bootstrapped on init

`init-memory.py` scans the project on first init:
- Reads `package.json` / `Cargo.toml` / `go.mod` / `pyproject.toml` → populates `stack.md`
- Reads `.env.example` → captures all env var names into `apis.md`
- Detects known frameworks (Next.js, React, Prisma, Express, Vitest, etc.)
- Creates blank `decisions.md` and `patterns.md` ready to fill

Memory is loaded into every session via `@.claude/PROJECT_MEMORY.md` in CLAUDE.md.

### Hallucination Guard — Auto-compact on 3 failures

The `PostToolUse` hook counts consecutive tool failures:
- `Read` / `Edit` targeting a file that doesn't exist
- `Bash` command not found
- `Edit` with `old_string` not present (agent invented code)

After **3 consecutive failures** it outputs:
```
CONTEXT MANAGER: Auto-compact triggered.
The agent has encountered 3 consecutive tool failures...
/compact
```

Claude sees this output and runs `/compact`, resetting context while preserving key information. Any successful tool call resets the counter.

### Subagent Model — Haiku forced globally

`settings.json` sets:
```json
"env": {
  "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
  "CLAUDE_CODE_SUBAGENT_MODEL_FORCE": "1"
}
```

`FORCE=1` overrides any per-subagent model definition. All background agents (Explore, Plan, general-purpose) run on `claude-haiku-4-5-20251001` — the cheapest and fastest model — regardless of what they request. **67% cost reduction on subagent usage.**

### Coding Rules — Injected on init

`/ctx init` writes `.claude/CODING_RULES.md` into every project:
- No comments unless logic is non-obvious
- No docstrings/annotations unless asked
- No features or error handling beyond the task
- No collateral refactoring
- No backwards-compat debris
- Minimal diffs — only what was asked

Loaded first in CLAUDE.md so it takes precedence over all other instructions.

---

## Cross-Agent Compatibility

| Agent | How context is delivered |
|---|---|
| Claude Code | Auto-loaded via CLAUDE.md `@` includes — nothing to do |
| Cursor | Paste `/ctx share` output into chat |
| GitHub Copilot Chat | Paste `/ctx share` output into chat |
| Any LLM | Pipe `.claude/CONTEXT.md` + `FILE_MAP.md` into system prompt |

---

## Compatibility

- **OS**: macOS, Linux (bash installer), Windows (PowerShell installer)
- **Python**: 3.8+ required for `generate-map.py` and `init-memory.py`
- **Claude Code**: Any version with hooks support
- **Git**: Optional — used to find project root; falls back to `pwd`
