"""Tests for plugin discovery and loading."""

from __future__ import annotations

import os
import tempfile
import unittest

from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.plugin import call_plugin_hook, resolve_plugin


class TestPluginResolver(unittest.TestCase):
    """resolve_plugin / call_plugin_hook tests."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "source")
        os.mkdir(self.source)

        self.ctx = WorktreeContext(
            source_repo=self.source,
            worktree_path="/tmp/fake-worktree",
            verbose=False,
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write_plugin(self, content: str) -> str:
        """Write plugin.py under .pi/worktree-hooks/ in source repo."""
        plugin_dir = os.path.join(self.source, ".pi", "worktree-hooks")
        os.makedirs(plugin_dir, exist_ok=True)
        plugin_path = os.path.join(plugin_dir, "plugin.py")
        with open(plugin_path, "w") as f:
            f.write(content)
        return plugin_path

    def test_no_plugin_returns_none(self) -> None:
        """When no plugin.py exists, resolve_plugin returns None."""
        plugin = resolve_plugin(self.source)
        self.assertIsNone(plugin)

    def test_plugin_discovered(self) -> None:
        """When plugin.py exists, resolve_plugin returns the module."""
        self._write_plugin(
            "def presetup(ctx): pass\n"
            "def clean(ctx): pass\n"
        )
        plugin = resolve_plugin(self.source)
        self.assertIsNotNone(plugin)
        self.assertTrue(hasattr(plugin, "presetup"))
        self.assertTrue(hasattr(plugin, "clean"))

    def test_plugin_hook_called(self) -> None:
        """call_plugin_hook should invoke the named hook."""
        self._write_plugin(
            "def presetup(ctx):\n"
            "    ctx.presetup_called = True\n"
        )
        plugin = resolve_plugin(self.source)
        call_plugin_hook(plugin, "presetup", self.ctx)
        self.assertTrue(getattr(self.ctx, "presetup_called", False))

    def test_plugin_hook_none_module(self) -> None:
        """call_plugin_hook(None, …) should silently no-op."""
        # Should not raise
        call_plugin_hook(None, "presetup", self.ctx)

    def test_plugin_hook_missing(self) -> None:
        """call_plugin_hook with a missing hook name should silently no-op."""
        self._write_plugin(
            "def presetup(ctx): pass\n"
            # no 'clean' function
        )
        plugin = resolve_plugin(self.source)
        # Should not raise
        call_plugin_hook(plugin, "clean", self.ctx)

    def test_plugin_presetup_and_clean_both_work(self) -> None:
        """Both presetup and clean hooks should work."""
        self._write_plugin(
            "def presetup(ctx): ctx.presetup_ok = True\n"
            "def clean(ctx): ctx.clean_ok = True\n"
        )
        plugin = resolve_plugin(self.source)
        call_plugin_hook(plugin, "presetup", self.ctx)
        call_plugin_hook(plugin, "clean", self.ctx)
        self.assertTrue(getattr(self.ctx, "presetup_ok", False))
        self.assertTrue(getattr(self.ctx, "clean_ok", False))

    def test_plugin_error_raised(self) -> None:
        """Exceptions in plugin hooks propagate to the caller."""
        self._write_plugin(
            "def presetup(ctx):\n"
            "    raise RuntimeError(\"plugin failed\")\n"
        )
        plugin = resolve_plugin(self.source)
        with self.assertRaises(RuntimeError):
            call_plugin_hook(plugin, "presetup", self.ctx)
