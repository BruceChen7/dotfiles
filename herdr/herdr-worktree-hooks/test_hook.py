#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Tests for hook.py: event → worktree-hooks argv mapping + real-CLI integration.

Run with: uv run python test_hook.py   (or: python3 test_hook.py)

Fixture tests inject a recording shim via HERDR_WT_HOOKS_BIN and need no
live herdr. The integration test drives the real ~/.local/bin/worktree-hooks
CLI against a throwaway git repo (skipped when git or the CLI is unavailable).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent / "hook.py"
REAL_WT_HOOKS = Path.home() / ".local/bin/worktree-hooks"


def _event_json(event: str, worktree_path: str, repo_root: str | None = None) -> str:
    """Build an EventEnvelope fixture matching herdr's payload shape."""
    data = {"type": event.replace(".", "_"), "worktree": {"path": worktree_path}}
    if repo_root is not None:
        data["workspace"] = {"worktree": {"repo_root": repo_root}}
    return json.dumps({"event": event, "data": data})


def _run_hook(env: dict, cwd: Path) -> subprocess.CompletedProcess:
    merged = dict(os.environ)
    merged.pop("HERDR_PLUGIN_EVENT", None)
    merged.pop("HERDR_PLUGIN_EVENT_JSON", None)
    merged.pop("HERDR_PLUGIN_CONTEXT_JSON", None)
    merged.update(env)
    return subprocess.run(
        [sys.executable, str(HOOK)],
        env=merged,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=60,
    )


class HookFixtureTests(unittest.TestCase):
    """Event mapping with a recording shim standing in for worktree-hooks."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="wt-hooks-test-"))
        self.record = self.tmp / "shim-argv.json"
        self.shim = self.tmp / "shim.py"
        self.shim.write_text(
            textwrap.dedent(
                """\
                #!/usr/bin/env python3
                import json, os, sys
                record = os.environ["SHIM_RECORD"]
                with open(record, "w") as fh:
                    json.dump(sys.argv[1:], fh)
                sys.exit(int(os.environ.get("SHIM_EXIT", "0")))
                """
            )
        )
        self.shim.chmod(0o755)
        self.env = {
            "HERDR_WT_HOOKS_BIN": str(self.shim),
            "SHIM_RECORD": str(self.record),
        }

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def recorded(self) -> list[str]:
        return json.loads(self.record.read_text())

    def test_created_maps_to_presetup(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.created"
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json(
            "worktree.created", "/repo/wt/worktree-foo"
        )
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.recorded(), ["presetup", "/repo/wt/worktree-foo"])

    def test_opened_maps_to_presetup(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.opened"
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json(
            "worktree.opened", "/repo/wt/worktree-bar"
        )
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.recorded(), ["presetup", "/repo/wt/worktree-bar"])

    def test_removed_maps_to_clean_with_repo_root(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.removed"
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json(
            "worktree.removed", "/repo/wt/worktree-foo", repo_root="/repo"
        )
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.recorded(), ["clean", "/repo", "/repo/wt/worktree-foo"]
        )

    def test_removed_falls_back_to_context_json(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.removed"
        # workspace snapshot absent (null per schema) → only CONTEXT_JSON has repo_root
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json(
            "worktree.removed", "/repo/wt/worktree-foo"
        )
        env["HERDR_PLUGIN_CONTEXT_JSON"] = json.dumps(
            {"worktree": {"repo_root": "/repo", "checkout_path": "/repo/wt/worktree-foo"}}
        )
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.recorded(), ["clean", "/repo", "/repo/wt/worktree-foo"]
        )

    def test_removed_without_repo_root_is_noop(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.removed"
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json(
            "worktree.removed", "/repo/wt/worktree-foo"
        )
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("cannot resolve source repo", result.stderr)
        self.assertFalse(self.record.exists())

    def test_missing_event_fails(self) -> None:
        result = _run_hook({}, self.tmp)
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing HERDR_PLUGIN_EVENT", result.stderr)

    def test_unknown_event_is_noop(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "tab.focused"
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json("tab.focused", "/repo")
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("unhandled event", result.stderr)
        self.assertFalse(self.record.exists())

    def test_missing_worktree_path_is_noop(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.created"
        env["HERDR_PLUGIN_EVENT_JSON"] = json.dumps(
            {"event": "worktree.created", "data": {"type": "worktree_created"}}
        )
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no worktree path", result.stderr)
        self.assertFalse(self.record.exists())

    def test_malformed_event_json_is_noop(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.created"
        env["HERDR_PLUGIN_EVENT_JSON"] = "{not json"
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.record.exists())

    def test_failure_exit_code_propagates(self) -> None:
        env = dict(self.env)
        env["HERDR_PLUGIN_EVENT"] = "worktree.created"
        env["HERDR_PLUGIN_EVENT_JSON"] = _event_json(
            "worktree.created", "/repo/wt/worktree-foo"
        )
        env["SHIM_EXIT"] = "7"
        result = _run_hook(env, self.tmp)
        self.assertEqual(result.returncode, 7)


@unittest.skipUnless(
    shutil.which("git"), "git is required for the integration test"
)
@unittest.skipUnless(REAL_WT_HOOKS.exists(), "~/.local/bin/worktree-hooks not found")
class RealCliIntegrationTest(unittest.TestCase):
    """Drive the real worktree-hooks CLI through hook.py's exact call shapes."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="wt-hooks-int-"))
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        self.checkout = self.tmp / "checkout"
        self.marks = self.tmp / "marks"
        self.marks.mkdir()

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _git(self, *args: str) -> None:
        subprocess.run(
            ["git", "-C", str(self.repo), *args],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_presetup_then_clean_end_to_end(self) -> None:
        # Source repo: tracked .gitignore; untracked artifacts (.pi, node_modules)
        # gitignored so the worktree checkout does NOT contain them — the real
        # scenario where presetup's symlinks matter.
        (self.repo / "README.md").write_text("test\n")
        (self.repo / ".gitignore").write_text("*.log\n.pi/\nnode_modules/\n")
        (self.repo / ".pi" / "worktree-hooks").mkdir(parents=True)
        (self.repo / ".pi" / "worktree-hooks" / "plugin.py").write_text(
            textwrap.dedent(
                f"""\
                from pathlib import Path
                MARK = Path({str(self.marks)!r})
                def presetup(ctx):
                    (MARK / "presetup").write_text(ctx.worktree_path + "\\n")
                def clean(ctx):
                    (MARK / "clean").write_text(
                        ctx.source_repo + "|" + ctx.worktree_path + "\\n")
                """
            )
        )
        (self.repo / "node_modules").mkdir()
        (self.repo / "node_modules" / "dep").write_text("x\n")
        self._git("init", "--quiet", "-b", "main")
        self._git("config", "user.email", "test@example.invalid")
        self._git("config", "user.name", "Test")
        self._git("add", "-A")
        self._git("commit", "--quiet", "-m", "initial")

        # Simulate herdr worktree.created: checkout exists → one positional arg.
        self._git("worktree", "add", "--quiet", "-b", "wt/test", str(self.checkout), "HEAD")
        self.assertFalse((self.checkout / ".pi").exists(), "untracked .pi must not be checked out")
        presetup = subprocess.run(
            [str(REAL_WT_HOOKS), "presetup", str(self.checkout)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        self.assertEqual(presetup.returncode, 0, presetup.stderr)
        self.assertTrue((self.checkout / ".pi").is_symlink(), "expected .pi symlink")
        self.assertTrue((self.checkout / "node_modules").is_symlink())
        self.assertTrue((self.checkout / ".gitignore").is_file(), "tracked .gitignore stays a real file")
        self.assertFalse((self.checkout / ".gitignore").is_symlink())
        self.assertEqual(
            (self.marks / "presetup").read_text().strip(), str(self.checkout)
        )

        # Simulate herdr worktree.removed: checkout deleted → two positional args.
        # --force mirrors herdr's confirmed-force flow: git refuses to remove a
        # checkout containing untracked files (the presetup symlinks qualify),
        # and herdr retries with --force after the user confirms.
        self._git("worktree", "remove", "--force", str(self.checkout))
        self.assertFalse(self.checkout.exists())
        clean = subprocess.run(
            [str(REAL_WT_HOOKS), "clean", str(self.repo), str(self.checkout)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        self.assertEqual(clean.returncode, 0, clean.stderr)
        self.assertEqual(
            (self.marks / "clean").read_text().strip(),
            f"{self.repo}|{self.checkout}",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
