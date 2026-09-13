#!/usr/bin/env python3
"""
init-memory.py — Initialize project memory for Context Manager
Scans the project and pre-populates .claude/MEMORY/ with structured knowledge.

Usage:
    python3 init-memory.py [project-root]
"""

import json
import sys
import re
from pathlib import Path
from datetime import date


def detect_stack(root: Path) -> dict:
    stack = {}

    # Node / npm
    pkg = root / 'package.json'
    if pkg.exists():
        try:
            data = json.loads(pkg.read_text(encoding='utf-8', errors='ignore'))
            stack['runtime'] = 'Node.js'
            stack['name'] = data.get('name', '')
            stack['description'] = data.get('description', '')
            all_deps = {
                **data.get('dependencies', {}),
                **data.get('devDependencies', {}),
            }
            stack['all_deps'] = list(all_deps.keys())

            frameworks = []
            if 'next' in all_deps:           frameworks.append('Next.js')
            if 'react' in all_deps:          frameworks.append('React')
            if '@remix-run/react' in all_deps: frameworks.append('Remix')
            if 'vue' in all_deps:            frameworks.append('Vue')
            if 'nuxt' in all_deps:           frameworks.append('Nuxt')
            if 'svelte' in all_deps:         frameworks.append('Svelte')
            if '@sveltejs/kit' in all_deps:  frameworks.append('SvelteKit')
            if 'express' in all_deps:        frameworks.append('Express')
            if 'fastify' in all_deps:        frameworks.append('Fastify')
            if 'hono' in all_deps:           frameworks.append('Hono')
            if 'prisma' in all_deps or '@prisma/client' in all_deps:
                                             frameworks.append('Prisma ORM')
            if 'drizzle-orm' in all_deps:    frameworks.append('Drizzle ORM')
            if 'mongoose' in all_deps:       frameworks.append('Mongoose')
            if 'trpc' in all_deps or '@trpc/server' in all_deps:
                                             frameworks.append('tRPC')
            if 'graphql' in all_deps:        frameworks.append('GraphQL')
            if 'tailwindcss' in all_deps:    frameworks.append('Tailwind CSS')
            if 'jest' in all_deps:           frameworks.append('Jest (testing)')
            if 'vitest' in all_deps:         frameworks.append('Vitest (testing)')
            if 'playwright' in all_deps or '@playwright/test' in all_deps:
                                             frameworks.append('Playwright (e2e)')
            stack['frameworks'] = frameworks

            scripts = list(data.get('scripts', {}).keys())
            stack['scripts'] = scripts
        except Exception:
            pass

    # Python
    pyproject = root / 'pyproject.toml'
    requirements = root / 'requirements.txt'
    if pyproject.exists():
        stack['runtime'] = 'Python'
        try:
            text = pyproject.read_text(encoding='utf-8', errors='ignore')
            m = re.search(r'name\s*=\s*"([^"]+)"', text)
            if m:
                stack['name'] = m.group(1)
            m = re.search(r'description\s*=\s*"([^"]+)"', text)
            if m:
                stack['description'] = m.group(1)
        except Exception:
            pass
    elif requirements.exists():
        stack['runtime'] = 'Python'
        try:
            deps = [
                l.strip().split('==')[0].split('>=')[0].split('[')[0]
                for l in requirements.read_text(encoding='utf-8', errors='ignore').split('\n')
                if l.strip() and not l.startswith('#')
            ]
            stack['all_deps'] = deps[:30]
        except Exception:
            pass

    # Rust
    cargo = root / 'Cargo.toml'
    if cargo.exists():
        stack['runtime'] = 'Rust'
        try:
            text = cargo.read_text(encoding='utf-8', errors='ignore')
            m = re.search(r'^name\s*=\s*"([^"]+)"', text, re.MULTILINE)
            if m:
                stack['name'] = m.group(1)
            m = re.search(r'^description\s*=\s*"([^"]+)"', text, re.MULTILINE)
            if m:
                stack['description'] = m.group(1)
        except Exception:
            pass

    # Go
    go_mod = root / 'go.mod'
    if go_mod.exists():
        stack['runtime'] = 'Go'
        try:
            text = go_mod.read_text(encoding='utf-8', errors='ignore')
            m = re.search(r'^module\s+(\S+)', text, re.MULTILINE)
            if m:
                stack['name'] = m.group(1)
        except Exception:
            pass

    # Ruby
    gemfile = root / 'Gemfile'
    if gemfile.exists():
        stack['runtime'] = 'Ruby'

    # .NET
    for f in root.glob('*.csproj'):
        stack['runtime'] = 'C# / .NET'
        stack['name'] = f.stem
        break

    return stack


def get_env_vars(root: Path) -> list:
    result = []
    for fname in ['.env.example', '.env.sample', '.env.template', '.env.local.example']:
        f = root / fname
        if f.exists():
            for line in f.read_text(encoding='utf-8', errors='ignore').split('\n'):
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key = line.split('=')[0].strip()
                    comment = ''
                    if '#' in line:
                        comment = line.split('#', 1)[1].strip()
                    result.append((key, comment))
    return result


def get_readme_description(root: Path) -> str:
    for fname in ['README.md', 'readme.md', 'README.txt', 'README']:
        f = root / fname
        if not f.exists():
            continue
        text = f.read_text(encoding='utf-8', errors='ignore')
        lines = text.split('\n')
        # Skip the title line, find the first paragraph of real text
        in_para = False
        para = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith('#'):
                if para:
                    break
                continue
            if stripped.startswith('![') or stripped.startswith('[!['):
                continue
            if stripped:
                para.append(stripped)
                in_para = True
            elif in_para:
                break
        if para:
            return ' '.join(para)[:300]
    return ''


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    memory_dir = root / '.claude' / 'MEMORY'
    memory_dir.mkdir(parents=True, exist_ok=True)
    today = date.today().isoformat()

    stack = detect_stack(root)
    env_vars = get_env_vars(root)
    readme_desc = get_readme_description(root)

    created = []

    # ── stack.md ─────────────────────────────────────────────────────────────
    lines = [
        "---",
        "name: Tech Stack",
        "description: Runtime, frameworks, and key dependencies detected from project config",
        "type: project",
        f"last_updated: {today}",
        "---",
        "",
        "## Runtime",
        f"- {stack.get('runtime', 'Unknown — update this')}",
    ]
    if stack.get('name'):
        lines += ["", "## Project", f"- **Name**: {stack['name']}"]
        if stack.get('description'):
            lines.append(f"- **Description**: {stack['description']}")

    if stack.get('frameworks'):
        lines += ["", "## Frameworks / Libraries"]
        for f in stack['frameworks']:
            lines.append(f"- {f}")

    if stack.get('all_deps'):
        shown = stack['all_deps'][:20]
        lines += ["", "## Key Dependencies"]
        for d in shown:
            lines.append(f"- {d}")
        if len(stack['all_deps']) > 20:
            lines.append(f"- ... and {len(stack['all_deps']) - 20} more (see package.json)")

    if stack.get('scripts'):
        lines += ["", "## Available Scripts"]
        for s in stack['scripts'][:10]:
            lines.append(f"- `{s}`")

    (memory_dir / 'stack.md').write_text('\n'.join(lines), encoding='utf-8')
    created.append('stack.md')

    # ── decisions.md ─────────────────────────────────────────────────────────
    lines = [
        "---",
        "name: Architectural Decisions",
        "description: Why things were built the way they were — record decisions and their reasons",
        "type: project",
        f"last_updated: {today}",
        "---",
        "",
        "## Decisions",
        "<!-- Format each as: Decision made — **Why:** reason — **How to apply:** guidance -->",
        "- ",
    ]
    (memory_dir / 'decisions.md').write_text('\n'.join(lines), encoding='utf-8')
    created.append('decisions.md')

    # ── apis.md ───────────────────────────────────────────────────────────────
    lines = [
        "---",
        "name: APIs and Services",
        "description: External services, APIs, and required environment variables",
        "type: project",
        f"last_updated: {today}",
        "---",
        "",
        "## Environment Variables",
    ]
    if env_vars:
        for key, comment in env_vars:
            if comment:
                lines.append(f"- `{key}` — {comment}")
            else:
                lines.append(f"- `{key}`")
    else:
        lines.append("- None detected (check .env.example if it exists)")

    lines += ["", "## External APIs / Services", "- "]
    (memory_dir / 'apis.md').write_text('\n'.join(lines), encoding='utf-8')
    created.append('apis.md')

    # ── patterns.md ───────────────────────────────────────────────────────────
    lines = [
        "---",
        "name: Code Patterns",
        "description: Conventions, patterns, and anti-patterns specific to this codebase",
        "type: project",
        f"last_updated: {today}",
        "---",
        "",
        "## Conventions",
        "<!-- File naming, import style, directory layout rules, state management approach -->",
        "- ",
        "",
        "## Anti-patterns",
        "<!-- Things that should NOT be done in this codebase — save debugging time for future agents -->",
        "- ",
    ]
    (memory_dir / 'patterns.md').write_text('\n'.join(lines), encoding='utf-8')
    created.append('patterns.md')

    # ── MEMORY.md index ───────────────────────────────────────────────────────
    project_name = stack.get('name') or root.name
    desc_line = f"  _{readme_desc}_" if readme_desc else ""
    lines = [
        f"# Project Memory — {project_name}",
        "_Auto-managed by Context Manager. Update entries as the project evolves._",
        f"{desc_line}",
        "",
        "## Memory Index",
        "- [Tech Stack](MEMORY/stack.md) — Runtime, frameworks, key dependencies",
        "- [Architectural Decisions](MEMORY/decisions.md) — Why things were built the way they were",
        "- [APIs and Services](MEMORY/apis.md) — External services, env vars, integrations",
        "- [Code Patterns](MEMORY/patterns.md) — Conventions and anti-patterns",
    ]
    # Write index to .claude/ (not MEMORY/) so @ include path is simpler
    (root / '.claude' / 'PROJECT_MEMORY.md').write_text('\n'.join(lines), encoding='utf-8')
    created.append('PROJECT_MEMORY.md (index)')

    print(f"Project memory initialized: {', '.join(created)}")
    print(f"Location: {memory_dir}")


if __name__ == '__main__':
    main()
