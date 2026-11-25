"""Tests for declarative command hooks (``worktree_hooks.hooks``)."""

from __future__ import annotations

import os
import tempfile
import unittest

from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.hooks import (
    Hook,
    load_hooks,
    parse_hooks,
    render_argv,
    render_cwd,
    run_hooks,
)


class TestParseHooks(unittest.TestCase):
    def test_reads_on_command_cwd(self) -> None:
        hooks = parse_hooks(
            {
                "hook": [
                    {
                        "on": "presetup",
                        "command": ["bash", "tools/x.sh", "{worktree}"],
                        "cwd": "{source}",
                    }
                ]
            }
        )
        self.assertEqual(
            hooks,
            [Hook("presetup", ("bash", "tools/x.sh", "{worktree}"), "{source}")],
        )

    def test_default_cwd_is_worktree(self) -> None:
        hooks = parse_hooks({"hook": [{"on": "clean", "command": ["true"]}]})
        self.assertEqual(hooks[0].cwd, "{worktree}")

    def test_bad_entries_are_skipped(self) -> None:
        hooks = parse_hooks(
            {
                "hook": [
                    {"on": "presetup"},  # 缺 command
                    {"on": "nope", "command": ["true"]},  # 未知事件
                    {"on": "clean", "command": ["true"]},
                ]
            }
        )
        self.assertEqual([hook.on for hook in hooks], ["clean"])

    def test_not_a_list_degrades(self) -> None:
        self.assertEqual(parse_hooks({"hook": "oops"}), [])


class TestRender(unittest.TestCase):
    def test_placeholders(self) -> None:
        ctx = WorktreeContext(source_repo="/src", worktree_path="/wt")
        hook = Hook(
            "presetup",
            ("bash", "tools/b.sh", "{worktree}", "{name}", "{source}"),
            "{source}/tools",
        )
        self.assertEqual(
            render_argv(hook, ctx),
            ["bash", "tools/b.sh", "/wt", "wt", "/src"],
        )
        self.assertEqual(render_cwd(hook, ctx), "/src/tools")

    def test_unknown_placeholder_is_left_alone(self) -> None:
        ctx = WorktreeContext(source_repo="/src", worktree_path="/wt")
        self.assertEqual(render_argv(Hook("clean", ("x", "{nope}")), ctx), ["x", "{nope}"])


class TestRunHooks(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "src")
        self.worktree = os.path.join(self._tmp.name, "wt")
        os.makedirs(os.path.join(self.source, ".pi"))
        os.makedirs(self.worktree)
        self._old = os.environ.get("WORKTREE_HOOKS_CONFIG")
        os.environ["WORKTREE_HOOKS_CONFIG"] = os.path.join(
            self._tmp.name, "no-config.toml"
        )
        self.ctx = WorktreeContext(self.source, self.worktree)

    def tearDown(self) -> None:
        if self._old is None:
            os.environ.pop("WORKTREE_HOOKS_CONFIG", None)
        else:
            os.environ["WORKTREE_HOOKS_CONFIG"] = self._old
        self._tmp.cleanup()

    def _declare(self, body: str) -> None:
        with open(os.path.join(self.source, ".pi", "worktree-hooks.toml"), "w") as fh:
            fh.write(body)

    def test_runs_only_matching_event(self) -> None:
        self._declare(
            '[[hook]]\n'
            'on = "presetup"\n'
            'command = ["touch", "{worktree}/prep"]\n'
            '[[hook]]\n'
            'on = "clean"\n'
            'command = ["touch", "{worktree}/gone"]\n'
        )
        self.assertEqual(run_hooks(self.ctx, "presetup"), 0)
        self.assertTrue(os.path.isfile(os.path.join(self.worktree, "prep")))
        self.assertFalse(os.path.lexists(os.path.join(self.worktree, "gone")))

    def test_dry_run_executes_nothing(self) -> None:
        self._declare('[[hook]]\non = "presetup"\ncommand = ["touch", "{worktree}/prep"]\n')
        self.assertEqual(run_hooks(self.ctx, "presetup", dry_run=True), 0)
        self.assertFalse(os.path.lexists(os.path.join(self.worktree, "prep")))

    def test_failure_is_counted_not_raised(self) -> None:
        """钩子失败只计数：presetup 不该因为某一步没成就中断。"""
        self._declare('[[hook]]\non = "presetup"\ncommand = ["false"]\n')
        self.assertEqual(run_hooks(self.ctx, "presetup"), 1)

    def test_missing_binary_is_counted(self) -> None:
        self._declare(
            '[[hook]]\non = "presetup"\ncommand = ["no-such-binary-xyz"]\n'
        )
        self.assertEqual(run_hooks(self.ctx, "presetup"), 1)

    def test_missing_cwd_is_counted(self) -> None:
        self._declare(
            '[[hook]]\non = "presetup"\ncwd = "{worktree}/nope"\n'
            'command = ["true"]\n'
        )
        self.assertEqual(run_hooks(self.ctx, "presetup"), 1)

    def test_load_merges_global_then_repo(self) -> None:
        global_cfg = os.environ["WORKTREE_HOOKS_CONFIG"]
        with open(global_cfg, "w") as fh:
            fh.write('[[hook]]\non = "presetup"\ncommand = ["global"]\n')
        self._declare('[[hook]]\non = "presetup"\ncommand = ["repo"]\n')
        self.assertEqual(
            [hook.command for hook in load_hooks(self.source)],
            [("global",), ("repo",)],
        )


if __name__ == "__main__":
    unittest.main()
