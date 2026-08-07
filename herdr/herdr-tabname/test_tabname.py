#!/usr/bin/env python3
"""
Tests for tabname.py — pure naming algorithm with fixture JSON.

Usage: uv run python test_tabname.py
"""

import unittest
from unittest.mock import patch
from pathlib import Path

# Import the module under test
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import tabname


# ---- Fixtures ------------------------------------------------------------


def _pane_get_response(
    *, display_agent: str | None = None, agent: str | None = None
) -> dict:
    """Build a fake herdr pane get response."""
    pane = {}
    if display_agent is not None:
        pane["display_agent"] = display_agent
    if agent is not None:
        pane["agent"] = agent
    return {"result": {"pane": pane}}


def _process_info_response(*, processes: list[dict]) -> dict:
    """Build a fake herdr pane process-info response."""
    return {"result": {"process_info": {"foreground_processes": processes}}}


class TestStatePath(unittest.TestCase):
    """State path must match herdr's injected/runtime convention."""

    def test_xdg_state_fallback_matches_herdr(self):
        with patch.dict(
            "os.environ",
            {"HERDR_PLUGIN_STATE_DIR": "", "XDG_STATE_HOME": "/tmp/herdr-state-test"},
            clear=False,
        ):
            self.assertEqual(
                tabname._state_dir(),
                Path("/tmp/herdr-state-test/herdr/plugins/herdr-tabname"),
            )

    def test_explicit_plugin_state_dir_wins(self):
        with patch.dict(
            "os.environ",
            {"HERDR_PLUGIN_STATE_DIR": "/tmp/injected-herdr-tabname-state"},
            clear=False,
        ):
            self.assertEqual(
                tabname._state_dir(),
                Path("/tmp/injected-herdr-tabname-state"),
            )


# ---- Tests ---------------------------------------------------------------


class TestComputeLabel(unittest.TestCase):
    """Test compute_label() with mocked _herdr."""

    # -- Agent priority ----------------------------------------------------

    def test_agent_display_agent_priority(self):
        """display_agent takes priority over agent."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response(display_agent="pi-coding", agent="codex")
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "pi-coding")

    def test_agent_fallback(self):
        """agent is used when display_agent is absent."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response(agent="codex")
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "codex")

    def test_agent_both_uses_display_agent(self):
        """Both present → display_agent wins."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response(display_agent="my-agent", agent="inner-agent")
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "my-agent")

    # -- Process name ------------------------------------------------------

    def test_process_name_simple(self):
        """Simple process name (vim)."""

        def fake_herdr(*args, **kwargs):
            cmd = tuple(args)
            if cmd == ("pane", "get", "p1"):
                return _pane_get_response()  # no agent
            if cmd == ("pane", "process-info", "--pane", "p1"):
                return _process_info_response(processes=[{"name": "vim"}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "vim")

    def test_process_name_normalized_agent(self):
        """Already-normalized agent name (codex)."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[{"name": "codex"}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "codex")

    # -- Shell → cwd basename ----------------------------------------------

    def test_shell_uses_cwd_basename(self):
        """Idle shell → cwd basename."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(
                    processes=[{"name": "zsh", "cwd": "/Users/x/work/dotfiles"}]
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "dotfiles")

    def test_shell_no_cwd_falls_back_to_shell_name(self):
        """Shell without cwd → shell name."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[{"name": "bash", "cwd": ""}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "bash")

    def test_shell_cwd_none_falls_back_to_shell_name(self):
        """Shell without cwd field → shell name."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(
                    processes=[{"name": "fish"}]
                )  # no cwd key
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "fish")

    # -- All shells in SHELL_NAMES -----------------------------------------

    def test_all_shells_use_cwd(self):
        """Every shell in SHELL_NAMES → cwd basename."""

        def make_fake(shell_name):
            def fake_herdr(*args, **kwargs):
                if args[0] == "pane" and args[1] == "get":
                    return _pane_get_response()
                if args[0] == "pane" and args[1] == "process-info":
                    return _process_info_response(
                        processes=[{"name": shell_name, "cwd": "/tmp/workspace"}]
                    )
                return None

            return fake_herdr

        for shell in sorted(tabname.SHELL_NAMES):
            with self.subTest(shell=shell):
                with patch("tabname._herdr", side_effect=make_fake(shell)):
                    self.assertEqual(tabname.compute_label("p1"), "workspace")

    # -- Empty / undetectable ----------------------------------------------

    def test_empty_process_list_returns_none(self):
        """No foreground processes → None (keep current name)."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertIsNone(tabname.compute_label("p1"))

    def test_herdr_api_failure_returns_none(self):
        """CLI failure → None."""
        with patch("tabname._herdr", return_value=None):
            self.assertIsNone(tabname.compute_label("p1"))

    # -- Basename ----------------------------------------------------------

    def test_basename_with_path(self):
        """Full path → basename."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[{"name": "/usr/bin/vim"}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "vim")

    # -- Truncation --------------------------------------------------------

    def test_long_name_truncated(self):
        """Name > MAX_LABEL_LENGTH → truncated."""
        long_name = "a" * (tabname.MAX_LABEL_LENGTH + 10)
        expected = "a" * tabname.MAX_LABEL_LENGTH

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[{"name": long_name}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), expected)

    def test_short_name_not_truncated(self):
        """Name ≤ MAX_LABEL_LENGTH → unchanged."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[{"name": "vim"}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "vim")


# ---- Utility tests -------------------------------------------------------


class TestHelpers(unittest.TestCase):
    """Test internal helper functions."""

    def test_is_numeric(self):
        self.assertTrue(tabname._is_numeric("1"))
        self.assertTrue(tabname._is_numeric("42"))
        self.assertFalse(tabname._is_numeric(""))
        self.assertFalse(tabname._is_numeric("vim"))
        self.assertFalse(tabname._is_numeric("t1"))

    def test_basename(self):
        self.assertEqual(tabname._basename("/usr/bin/vim"), "vim")
        self.assertEqual(tabname._basename("vim"), "vim")
        self.assertEqual(tabname._basename("/"), "")
        self.assertEqual(tabname._basename(""), "")

    def test_truncate(self):
        self.assertEqual(tabname._truncate("hello", 5), "hello")
        self.assertEqual(tabname._truncate("hello world", 5), "hello")
        self.assertEqual(tabname._truncate("", 5), "")


if __name__ == "__main__":
    unittest.main()
