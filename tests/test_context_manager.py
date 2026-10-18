#!/usr/bin/env python3
"""End-to-end checks for the Codex Context Manager installation path."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class ContextManagerCodexTests(unittest.TestCase):
    def run_command(self, args: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            cwd=REPO_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=True,
        )

    def test_init_context_creates_codex_project_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / "example-project"
            project.mkdir()
            (project / "package.json").write_text(
                '{"name":"example-project","dependencies":{"express":"^5.0.0"}}',
                encoding="utf-8",
            )
            (project / ".env.example").write_text("API_KEY=\n", encoding="utf-8")
            (project / "app.py").write_text("# Example application\n", encoding="utf-8")

            result = self.run_command(
                ["python3", "scripts/init-context.py", str(project), "--host", "codex"]
            )

            self.assertIn("Context Manager initialized", result.stdout)
            context_dir = project / ".claude"
            for relative_path in (
                "CONTEXT.md",
                "CODING_RULES.md",
                "FILE_MAP.md",
                "PROJECT_MEMORY.md",
                "MEMORY/stack.md",
                "MEMORY/apis.md",
                "MEMORY/decisions.md",
                "MEMORY/patterns.md",
            ):
                self.assertTrue((context_dir / relative_path).is_file(), relative_path)

            agents = (project / "AGENTS.md").read_text(encoding="utf-8")
            self.assertEqual(agents.count("<!-- context-manager:start -->"), 1)
            self.assertIn("`context-manager` skill", agents)
            self.assertIn("API_KEY", (context_dir / "MEMORY/apis.md").read_text(encoding="utf-8"))

            self.run_command(["python3", "scripts/init-context.py", str(project), "--host", "codex"])
            self.assertEqual(
                (project / "AGENTS.md").read_text(encoding="utf-8").count("<!-- context-manager:start -->"),
                1,
            )

    def test_codex_installer_copies_a_complete_skill(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            codex_home = home / "custom-codex"
            env = os.environ | {"HOME": str(home), "CODEX_HOME": str(codex_home)}

            result = self.run_command(["bash", "install.sh", "--codex"], env=env)

            self.assertIn("Codex skill", result.stdout)
            skill_dir = codex_home / "skills" / "context-manager"
            skill = skill_dir / "SKILL.md"
            self.assertTrue(skill.is_file())
            self.assertTrue((skill_dir / "scripts" / "generate-map.py").is_file())
            self.assertTrue((skill_dir / "scripts" / "init-memory.py").is_file())
            self.assertTrue((skill_dir / "scripts" / "init-context.py").is_file())
            content = skill.read_text(encoding="utf-8")
            self.assertTrue(content.startswith("---\nname: context-manager\n"))
            self.assertIn("Codex", content)

    def test_all_installer_keeps_the_claude_install_path_working(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            env = os.environ | {"HOME": str(home), "CODEX_HOME": str(home / "codex")}

            self.run_command(["bash", "install.sh", "--all"], env=env)

            claude_dir = home / ".claude"
            self.assertTrue((claude_dir / "skills" / "context-manager.md").is_file())
            self.assertTrue((claude_dir / "scripts" / "init-context.py").is_file())
            self.assertTrue((claude_dir / "hooks" / "file-map-hook.sh").is_file())
            settings = (claude_dir / "settings.json").read_text(encoding="utf-8")
            self.assertIn("CLAUDE_CODE_SUBAGENT_MODEL", settings)
            self.assertIn("file-map-hook", settings)


if __name__ == "__main__":
    unittest.main()
