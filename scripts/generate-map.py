#!/usr/bin/env python3
"""
generate-map.py — Project file map generator for Claude Code Context Manager
Produces a FILE_MAP.md that exploration agents can read instead of scanning the repo.

Usage:
    python3 generate-map.py [project-root]
    python3 generate-map.py [project-root] --output .claude/FILE_MAP.md
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import date

# ── Directories to always skip ───────────────────────────────────────────────
SKIP_DIRS = {
    '.git', 'node_modules', '__pycache__', '.next', '.nuxt',
    'dist', 'build', 'out', 'target', '.venv', 'venv', 'env',
    'coverage', '.nyc_output', '.pytest_cache', '.mypy_cache',
    '.cargo', 'vendor', 'bin', 'obj', '.turbo', '.cache',
    'storybook-static', '.parcel-cache', 'eggs', '.eggs',
    'htmlcov', '.tox', '.nox', 'site-packages',
}

# ── File extensions to skip (binaries, compiled artifacts) ───────────────────
SKIP_EXTENSIONS = {
    '.pyc', '.pyo', '.pyd', '.class', '.o', '.so', '.dll',
    '.exe', '.bin', '.wasm', '.map', '.snap', '.lock',
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg', '.webp',
    '.mp4', '.mp3', '.wav', '.ttf', '.woff', '.woff2', '.eot',
    '.zip', '.tar', '.gz', '.rar', '.7z', '.pdf',
}

# ── Dotfiles/dotdirs that ARE worth showing ───────────────────────────────────
ALLOWED_DOTNAMES = {
    '.claude', '.github', '.vscode', '.env.example',
    '.eslintrc', '.eslintrc.js', '.eslintrc.json',
    '.prettierrc', '.prettierrc.json', '.prettierrc.js',
    '.babelrc', '.babelrc.json',
    '.dockerignore', '.gitignore', '.gitattributes',
    '.editorconfig', '.nvmrc', '.python-version',
    'Dockerfile', 'docker-compose.yml', 'docker-compose.yaml',
}

MAX_DEPTH = 6
MAX_FILES_PER_DIR = 40  # Collapse dirs with more than this many files


def read_gitignore(root: Path) -> set:
    patterns = set()
    for gi_path in [root / '.gitignore', root / '.claudeignore']:
        if gi_path.exists():
            for line in gi_path.read_text(encoding='utf-8', errors='ignore').split('\n'):
                line = line.strip().rstrip('/')
                if line and not line.startswith('#'):
                    patterns.add(line)
    return patterns


def is_ignored(name: str, gitignore: set) -> bool:
    if name in gitignore:
        return True
    for pattern in gitignore:
        # Simple glob: pattern without slashes matches any file/dir of that name
        if '/' not in pattern and name == pattern:
            return True
        # Pattern ending with * (e.g. *.log)
        if pattern.startswith('*') and name.endswith(pattern[1:]):
            return True
    return False


def should_skip_dir(name: str, gitignore: set) -> bool:
    if name in SKIP_DIRS:
        return True
    if name.startswith('.') and name not in ALLOWED_DOTNAMES:
        return True
    if is_ignored(name, gitignore):
        return True
    return False


def should_skip_file(path: Path, gitignore: set) -> bool:
    if path.suffix.lower() in SKIP_EXTENSIONS:
        return True
    if path.name.startswith('.') and path.name not in ALLOWED_DOTNAMES:
        return True
    if is_ignored(path.name, gitignore):
        return True
    # Skip very large files (>500KB) — not useful as context
    try:
        if path.stat().st_size > 500_000:
            return True
    except OSError:
        return True
    return False


def get_description(path: Path) -> str:
    """Infer a one-line description for a file."""
    name = path.name.lower()
    stem = path.stem.lower()

    # ── Well-known filenames ─────────────────────────────────────────────────
    known = {
        'readme.md': 'Project readme',
        'readme.txt': 'Project readme',
        'license': 'License file',
        'license.md': 'License file',
        'claude.md': 'Claude Code instructions (auto-loaded)',
        'context.md': 'Auto-managed project context',
        'file_map.md': 'Auto-generated file map',
        'dockerfile': 'Docker image definition',
        'docker-compose.yml': 'Docker Compose services',
        'docker-compose.yaml': 'Docker Compose services',
        '.gitignore': 'Git ignore rules',
        '.dockerignore': 'Docker ignore rules',
        '.env.example': 'Environment variable template',
        '.editorconfig': 'Editor formatting config',
        '.nvmrc': 'Node version pin',
        '.python-version': 'Python version pin',
        'makefile': 'Build targets',
        'justfile': 'Just task runner',
        'procfile': 'Process definitions (Heroku/etc)',
        'vercel.json': 'Vercel deployment config',
        'netlify.toml': 'Netlify deployment config',
        'fly.toml': 'Fly.io deployment config',
        'railway.json': 'Railway deployment config',
        'render.yaml': 'Render deployment config',
    }
    if name in known:
        return known[name]

    # ── Config files by extension ────────────────────────────────────────────
    ext = path.suffix.lower()
    if name == 'package.json':
        try:
            data = json.loads(path.read_text(encoding='utf-8', errors='ignore'))
            desc = data.get('description', '')
            return desc[:80] if desc else 'NPM package manifest'
        except Exception:
            return 'NPM package manifest'

    if name == 'cargo.toml':
        try:
            text = path.read_text(encoding='utf-8', errors='ignore')
            for line in text.split('\n'):
                if line.startswith('description'):
                    return line.split('=', 1)[-1].strip().strip('"')[:80]
        except Exception:
            pass
        return 'Rust crate manifest'

    if name == 'pyproject.toml':
        return 'Python project config (PEP 517/518)'

    if name == 'go.mod':
        return 'Go module definition'

    if name in ('tsconfig.json', 'jsconfig.json'):
        return 'TypeScript/JS compiler config'

    if name in ('vite.config.ts', 'vite.config.js'):
        return 'Vite bundler config'

    if name in ('next.config.js', 'next.config.ts', 'next.config.mjs'):
        return 'Next.js config'

    if name in ('tailwind.config.js', 'tailwind.config.ts'):
        return 'Tailwind CSS config'

    if name in ('jest.config.js', 'jest.config.ts'):
        return 'Jest test config'

    if name in ('vitest.config.ts', 'vitest.config.js'):
        return 'Vitest config'

    if name in ('eslint.config.js', '.eslintrc.json', '.eslintrc.js'):
        return 'ESLint rules'

    if ext in ('.prisma',):
        return 'Prisma database schema'

    if ext in ('.graphql', '.gql'):
        return 'GraphQL schema/query'

    if ext == '.sql' and 'migration' in stem:
        return 'Database migration'

    if ext == '.sql':
        return 'SQL query/schema'

    # ── Try reading first meaningful comment ─────────────────────────────────
    comment_starters = {
        '.py': ('#', '"""', "'''"),
        '.ts': ('//', '/*'),
        '.tsx': ('//', '/*'),
        '.js': ('//', '/*'),
        '.jsx': ('//', '/*'),
        '.rs': ('//', '//!', '/*'),
        '.go': ('//', '/*'),
        '.rb': ('#',),
        '.sh': ('#',),
        '.bash': ('#',),
        '.zsh': ('#',),
        '.md': ('# ',),
        '.swift': ('//', '/*'),
        '.kt': ('//', '/*'),
        '.java': ('//', '/*'),
        '.c': ('//', '/*'),
        '.cpp': ('//', '/*'),
        '.h': ('//', '/*'),
    }

    starters = comment_starters.get(ext, ())
    if starters:
        try:
            text = path.read_text(encoding='utf-8', errors='ignore')
            lines = text.split('\n')
            for line in lines[:10]:
                stripped = line.strip()
                if not stripped:
                    continue
                # Skip shebangs
                if stripped.startswith('#!'):
                    continue
                for s in starters:
                    if stripped.startswith(s):
                        desc = stripped[len(s):].strip().rstrip('*/').strip()
                        if desc and len(desc) > 3:
                            return desc[:80]
                # Stop at first non-comment non-empty line
                if not any(stripped.startswith(s) for s in starters):
                    break
        except Exception:
            pass

    return ''


def generate_tree(
    root: Path,
    depth: int = 0,
    prefix: str = '',
    gitignore: set = None,
) -> list[str]:
    if gitignore is None:
        gitignore = set()

    lines = []
    try:
        entries = sorted(root.iterdir(), key=lambda x: (x.is_file(), x.name.lower()))
    except PermissionError:
        return lines

    dirs  = [e for e in entries if e.is_dir()  and not should_skip_dir(e.name, gitignore)]
    files = [e for e in entries if e.is_file() and not should_skip_file(e, gitignore)]

    # Collapse huge dirs at the file level
    show_files = files
    collapsed_count = 0
    if len(files) > MAX_FILES_PER_DIR:
        show_files = files[:MAX_FILES_PER_DIR]
        collapsed_count = len(files) - MAX_FILES_PER_DIR

    all_entries = dirs + show_files

    for i, entry in enumerate(all_entries):
        is_last = (i == len(all_entries) - 1) and collapsed_count == 0
        connector = '└── ' if is_last else '├── '
        child_prefix = '    ' if is_last else '│   '

        if entry.is_dir():
            lines.append(f"{prefix}{connector}{entry.name}/")
            if depth < MAX_DEPTH:
                # Pass parent gitignore down; also check for nested .gitignore
                sub_gi = set(gitignore)
                sub_gi.update(read_gitignore(entry))
                lines.extend(generate_tree(entry, depth + 1, prefix + child_prefix, sub_gi))
            else:
                lines.append(f"{prefix}{child_prefix}[... truncated at depth {MAX_DEPTH}]")
        else:
            desc = get_description(entry)
            suffix = f'  ← {desc}' if desc else ''
            lines.append(f"{prefix}{connector}{entry.name}{suffix}")

    if collapsed_count:
        lines.append(f"{prefix}└── ... and {collapsed_count} more files")

    return lines


def main():
    parser = argparse.ArgumentParser(description='Generate project file map')
    parser.add_argument('root', nargs='?', default='.', help='Project root directory')
    parser.add_argument('--output', '-o', help='Output file path (default: stdout)')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    today = date.today().isoformat()

    gitignore = read_gitignore(root)

    output_lines = [
        f"## File Map",
        f"_Auto-generated by Context Manager · Last updated: {today}_",
        f"",
        f"> Use this map instead of running file-system exploration tools.",
        "> Run `/ctx map` to regenerate manually.",
        f"",
        f"```",
        f"{root.name}/",
    ]
    output_lines.extend(generate_tree(root, gitignore=gitignore))
    output_lines.append("```")
    output_lines.append("")

    # Count stats
    total_lines = len(output_lines)
    output_lines.append(f"_Map covers {root.name}. Excludes: node_modules, build artifacts, binaries, hidden dirs._")

    content = '\n'.join(output_lines)

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(content, encoding='utf-8')
    else:
        sys.stdout.buffer.write(content.encode('utf-8'))


if __name__ == '__main__':
    main()
