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


def _git(repo: str, *args: str) -> None:
    """在 *repo* 下跑 git。

    固定 ``init.defaultBranch=main`` 并让每个用例自设 identity，隔离环境配置。
    """
    subprocess.run(
        ["git", "-c", "init.defaultBranch=main", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
        timeout=30,
    )


def _write(path: str, content: str = "") -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(content)


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
        """presetup: `.pi` 是真目录，未跟踪条目为链接，tracked 保持普通文件。"""
        # setUp 里 `.pi` 为空目录；先补出「部分跟踪」形状：
        # tracked 文件提交，plans/ 留作未跟踪条目
        _write(os.path.join(self.source, ".pi", "tracked", "s.md"), "branch\n")
        _write(os.path.join(self.source, ".pi", "plans", "p.md"), "plan\n")
        _git(self.source, "add", ".pi/tracked/s.md")
        _git(self.source, "commit", "-q", "-m", "track pi")

        # 模拟 checkout：worktree 侧 tracked 文件已经以普通文件落地
        tracked_dst = os.path.join(self.worktree, ".pi", "tracked", "s.md")
        _write(tracked_dst, "branch\n")

        result = run_cli(
            "-v", "presetup", self.source, self.worktree,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        wt_pi = os.path.join(self.worktree, ".pi")
        # `.pi` 必须是真目录：整目录 symlink 会把 worktree 写操作带回主 checkout
        self.assertFalse(os.path.islink(wt_pi))
        self.assertTrue(os.path.isdir(wt_pi))
        # 未跟踪条目镜像为指向「源条目自身」的链接
        plans = os.path.join(wt_pi, "plans")
        self.assertTrue(os.path.islink(plans))
        self.assertEqual(
            os.readlink(plans), os.path.join(self.source, ".pi", "plans")
        )
        # tracked 路径属于本分支，presetup 不得覆盖成链接
        self.assertFalse(os.path.islink(tracked_dst))
        with open(tracked_dst) as fh:
            self.assertEqual(fh.read(), "branch\n")
        # node_modules / .gitignore 仍是整路径 symlink（行为不变）
        for artifact in ("node_modules", ".gitignore"):
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


class TestCLIRealWorktree(unittest.TestCase):
    """真实 `git worktree add` 端到端：presetup 后顶层一致，clean 后链接消失。"""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.source = os.path.join(self._tmp.name, "owner")
        self.worktree = os.path.join(self._tmp.name, "wt")

        _write(os.path.join(self.source, ".pi", "tracked", "s.md"), "branch\n")
        _write(os.path.join(self.source, ".pi", "plans", "p.md"), "plan\n")
        _write(os.path.join(self.source, ".pi", "lessons.md"), "lessons\n")
        # 忽略 `.pi` 顶层但放行 tracked/ —— 复刻真实仓库的混合 `.pi`
        _write(
            os.path.join(self.source, ".gitignore"),
            "/.pi/*\n!/.pi/tracked/\n",
        )

        _git(self.source, "init", "-q")
        _git(self.source, "config", "user.email", "test@example.com")
        _git(self.source, "config", "user.name", "Test")
        _git(self.source, "add", ".gitignore", ".pi/tracked/s.md")
        _git(self.source, "commit", "-q", "-m", "init")
        _git(
            self.source,
            "worktree", "add", self.worktree, "-b", "wt-test", "HEAD",
        )

    def test_presetup_then_clean_round_trip(self) -> None:
        result = run_cli("presetup", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        src_pi = os.path.join(self.source, ".pi")
        wt_pi = os.path.join(self.worktree, ".pi")
        # plan Goal 判据：worktree 顶层与主 checkout 顶层逐条一致
        self.assertEqual(sorted(os.listdir(wt_pi)), sorted(os.listdir(src_pi)))
        self.assertFalse(os.path.islink(wt_pi))
        lessons = os.path.join(wt_pi, "lessons.md")
        self.assertTrue(os.path.islink(lessons))
        self.assertEqual(os.readlink(lessons), os.path.join(src_pi, "lessons.md"))
        # tracked 文件由 git checkout 落地，不能被镜像覆盖成链接
        tracked = os.path.join(wt_pi, "tracked", "s.md")
        self.assertFalse(os.path.islink(tracked))
        with open(tracked) as fh:
            self.assertEqual(fh.read(), "branch\n")

        result = run_cli("clean", self.source, self.worktree)
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        # clean 回收镜像链接，但保留 tracked 内容与本分支的 `.pi/tracked/`
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "lessons.md")))
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "plans")))
        self.assertTrue(os.path.isfile(tracked))
        self.assertTrue(os.path.isdir(wt_pi))


if __name__ == "__main__":
    unittest.main()
