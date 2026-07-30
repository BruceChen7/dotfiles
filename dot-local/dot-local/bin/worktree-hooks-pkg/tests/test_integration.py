"""Integration tests — run the CLI end-to-end with subprocess."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest

PACKAGE_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), ".."),
)


def run_cli(*args: str, cwd: str = "") -> subprocess.CompletedProcess:
    """Run *worktree-hooks* via ``uv run`` in the package dir."""
    cmd = ["uv", "run", "--directory", PACKAGE_DIR, "worktree-hooks", *args]
    env = os.environ.copy()
    if cwd:
        env["PWD"] = os.path.abspath(cwd)
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=cwd or None,
        timeout=30,
        env=env,
    )


class TestCLIIntegration(unittest.TestCase):
    """Full CLI integration tests using subprocess and temp dirs."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "source")
        self.worktree = os.path.join(self._tmp.name, "worktree")
        os.mkdir(self.source)
        os.mkdir(self.worktree)

        # Create source artifacts
        os.mkdir(os.path.join(self.source, ".pi"))
        os.mkdir(os.path.join(self.source, "node_modules"))
        with open(os.path.join(self.source, ".gitignore"), "w") as f:
            f.write("*.pyc\n")

        # Init a git repo in source so source-repo auto-derivation works
        subprocess.run(
            ["git", "init"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "config", "user.email", "test@test"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "add", "."],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "commit", "-m", "initial"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )

        # Init a git repo in worktree and record the source as the common dir
        subprocess.run(
            ["git", "init"],
            cwd=self.worktree,
            capture_output=True,
            timeout=10,
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # -- presetup ----------------------------------------------------------

    def test_presetup_with_explicit_paths(self) -> None:
        """presetup with explicit source + worktree should create symlinks."""
        result = run_cli(
            "-v", "presetup", self.source, self.worktree,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        for artifact in (".pi", "node_modules", ".gitignore"):
            dst = os.path.join(self.worktree, artifact)
            self.assertTrue(os.path.islink(dst), f"{artifact} should be a symlink")

    def test_presetup_no_verbose(self) -> None:
        """presetup without -v should work silently."""
        result = run_cli("presetup", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)

    # -- clean -------------------------------------------------------------

    def test_clean_removes_symlinks(self) -> None:
        """clean should remove symlinks created by presetup."""
        # First run presetup
        run_cli("presetup", self.source, self.worktree)

        # Then clean
        result = run_cli("clean", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        for artifact in (".pi", "node_modules", ".gitignore"):
            dst = os.path.join(self.worktree, artifact)
            self.assertFalse(os.path.islink(dst), f"{artifact} should be removed")

    # -- list --------------------------------------------------------------

    def test_list_no_plugin(self) -> None:
        """list should report no plugin when none exists."""
        result = run_cli("list", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("(none)", result.stderr)

    # -- errors ------------------------------------------------------------

    def test_invalid_command(self) -> None:
        """An unknown command should exit with code 2."""
        result = run_cli("nonexistent")
        self.assertEqual(result.returncode, 2)

    def test_no_git_repo(self) -> None:
        """Outside a git repo with no explicit args should error."""
        with tempfile.TemporaryDirectory() as tmp:
            result = run_cli("presetup", cwd=tmp)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Cannot determine source repository", result.stderr)

    def test_explicit_paths_outside_git(self) -> None:
        """Explicit paths should work even outside git repos."""
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, "src")
            wt = os.path.join(tmp, "wt")
            os.mkdir(src)
            os.mkdir(wt)
            os.mkdir(os.path.join(src, ".pi"))

            result = run_cli("presetup", src, wt)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertTrue(os.path.islink(os.path.join(wt, ".pi")))


class TestCLIWithPlugin(unittest.TestCase):
    """Integration tests with a real project plugin."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "source")
        self.worktree = os.path.join(self._tmp.name, "worktree")
        os.mkdir(self.source)
        os.mkdir(self.worktree)

        # Source artifacts
        os.mkdir(os.path.join(self.source, ".pi"))
        os.mkdir(os.path.join(self.source, "node_modules"))
        with open(os.path.join(self.source, ".gitignore"), "w") as f:
            f.write("*.pyc\n")

        # Write a plugin
        plugin_dir = os.path.join(
            self.source, ".pi", "worktree-hooks",
        )
        os.makedirs(plugin_dir, exist_ok=True)
        with open(os.path.join(plugin_dir, "plugin.py"), "w") as f:
            f.write(
                "def presetup(ctx):\n"
                "    import os\n"
                '    marker = os.path.join(ctx.worktree_path, ".plugin-ran")\n'
                "    with open(marker, \"w\") as fh:\n"
                '        fh.write("ok")\n'
                "def clean(ctx):\n"
                "    import os\n"
                '    marker = os.path.join(ctx.worktree_path, ".plugin-ran")\n'
                "    if os.path.exists(marker):\n"
                "        os.unlink(marker)\n"
            )

        # Git init so source-repo derivation works
        subprocess.run(
            ["git", "init"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "config", "user.email", "test@test"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "add", "."],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "commit", "-m", "initial"],
            cwd=self.source,
            capture_output=True,
            timeout=10,
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_plugin_executed_after_defaults(self) -> None:
        """Plugin.presetup runs after default symlinks are created."""
        result = run_cli("presetup", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        # Defaults created symlinks
        self.assertTrue(os.path.islink(os.path.join(self.worktree, ".pi")))
        # Plugin created its marker
        self.assertTrue(
            os.path.isfile(os.path.join(self.worktree, ".plugin-ran")),
        )

    def test_plugin_clean_before_defaults(self) -> None:
        """Plugin.clean runs before default symlink removal."""
        # Setup
        run_cli("presetup", self.source, self.worktree)
        self.assertTrue(os.path.isfile(os.path.join(self.worktree, ".plugin-ran")))

        # Clean
        result = run_cli("clean", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        # Plugin marker should be gone (plugin.clean ran)
        self.assertFalse(
            os.path.isfile(os.path.join(self.worktree, ".plugin-ran")),
        )
        # Symlinks should also be gone
        self.assertFalse(os.path.islink(os.path.join(self.worktree, ".pi")))

    def test_list_shows_plugin_hooks(self) -> None:
        """list should report the plugin's hooks."""
        result = run_cli("list", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("presetup", result.stderr)
        self.assertIn("clean", result.stderr)


if __name__ == "__main__":
    unittest.main()
