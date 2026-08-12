#!/usr/bin/env python3
"""
Tests for tabname.py — pure naming algorithm with fixture JSON.

Usage: uv run python test_tabname.py
"""

import json
import tempfile
import time
import unittest
from unittest.mock import patch
from pathlib import Path

# Import the module under test
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import tabname


# ---- Fixtures ------------------------------------------------------------


def _pane_get_response(
    *,
    display_agent: str | None = None,
    agent: str | None = None,
    cwd: str | None = None,
) -> dict:
    """Build a fake herdr pane get response."""
    pane = {}
    if display_agent is not None:
        pane["display_agent"] = display_agent
    if agent is not None:
        pane["agent"] = agent
    if cwd is not None:
        pane["cwd"] = cwd
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
        """display_agent takes priority over agent; combined with cwd."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response(
                    display_agent="pi-coding",
                    agent="codex",
                    cwd=str(Path.home() / "work" / "dotfiles"),
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "pi-coding - ~/work/dotfiles")

    def test_agent_combined_with_cwd(self):
        """Agent + working directory → `agent - ~/path` (herdr's `π - dir` style)."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response(
                    agent="pi", cwd=str(Path.home() / "work" / "dotfiles")
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "pi - ~/work/dotfiles")

    def test_agent_uses_foreground_cwd_fallback(self):
        """Agent without `cwd` but with `foreground_cwd` → still combined."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return {
                    "result": {
                        "pane": {
                            "agent": "codex",
                            "foreground_cwd": "/opt/app",
                        }
                    }
                }
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "codex - /opt/app")

    def test_agent_fallback(self):
        """Agent without cwd → name only."""

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
                return _pane_get_response(
                    display_agent="my-agent",
                    agent="inner-agent",
                    cwd=str(Path.home() / "work" / "dotfiles"),
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "my-agent - ~/work/dotfiles")

    # -- Process working directory ------------------------------------------

    def test_process_uses_cwd_full_path(self):
        """Foreground process → full cwd path (home collapsed to ~)."""

        def fake_herdr(*args, **kwargs):
            cmd = tuple(args)
            if cmd == ("pane", "get", "p1"):
                return _pane_get_response()  # no agent
            if cmd == ("pane", "process-info", "--pane", "p1"):
                return _process_info_response(
                    processes=[
                        {"name": "nvim", "cwd": str(Path.home() / "work" / "dotfiles")}
                    ]
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "~/work/dotfiles")

    def test_process_cwd_outside_home_shown_absolute(self):
        """cwd outside home → absolute path unchanged."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(
                    processes=[{"name": "node", "cwd": "/opt/app/server"}]
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "/opt/app/server")

    def test_process_cwd_is_home(self):
        """cwd == home → `~`."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(
                    processes=[{"name": "bash", "cwd": str(Path.home())}]
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "~")

    def test_process_name_fallback_without_cwd(self):
        """Process without cwd → process name (vim)."""

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
        """Already-normalized agent name (codex) without cwd → name."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(processes=[{"name": "codex"}])
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "codex")

    # -- Shell → cwd full path ----------------------------------------------

    def test_shell_uses_cwd_full_path(self):
        """Idle shell → full cwd path (home collapsed to ~)."""

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(
                    processes=[
                        {"name": "zsh", "cwd": str(Path.home() / "work" / "dotfiles")}
                    ]
                )
            return None

        with patch("tabname._herdr", side_effect=fake_herdr):
            self.assertEqual(tabname.compute_label("p1"), "~/work/dotfiles")

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

    def test_long_path_head_truncated(self):
        """Long cwd path → head dropped, tail (project name) kept."""
        long_path = "/" + "x" * (tabname.MAX_LABEL_LENGTH + 30)
        expected = "…" + long_path[-(tabname.MAX_LABEL_LENGTH - 1) :]

        def fake_herdr(*args, **kwargs):
            if args[0] == "pane" and args[1] == "get":
                return _pane_get_response()
            if args[0] == "pane" and args[1] == "process-info":
                return _process_info_response(
                    processes=[{"name": "zsh", "cwd": long_path}]
                )
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

    def test_display_path_collapses_home(self):
        """Paths under home → `~` prefix."""
        with patch.object(Path, "home", return_value=Path("/Users/x")):
            self.assertEqual(
                tabname._display_path("/Users/x/work/dotfiles"), "~/work/dotfiles"
            )
            self.assertEqual(tabname._display_path("/Users/x"), "~")
            self.assertEqual(tabname._display_path("/Users/xy/work"), "/Users/xy/work")

    def test_display_path_outside_home_unchanged(self):
        self.assertEqual(tabname._display_path("/opt/app"), "/opt/app")

    def test_truncate_path_keeps_tail(self):
        self.assertEqual(
            tabname._truncate_path("~/work/dotfiles", 50), "~/work/dotfiles"
        )
        long = "/" + "a" * 60
        self.assertEqual(tabname._truncate_path(long, 50), "…" + "a" * 49)
        self.assertEqual(len(tabname._truncate_path(long, 50)), 50)


# ---- pane.updated handler tests -------------------------------------------


class TestHandlePaneUpdated(unittest.TestCase):
    """_handle_pane_updated(): title changes re-derive the tab label."""

    def setUp(self):
        self.state_dir = tempfile.mkdtemp(prefix="herdr-tabname-test-")
        self.env = {
            "HERDR_PLUGIN_STATE_DIR": self.state_dir,
            "HERDR_PLUGIN_EVENT": "pane.updated",
            "HERDR_PANE_ID": "",
            "HERDR_TAB_ID": "",
            "HERDR_PLUGIN_EVENT_JSON": "",
        }

    def _state_path(self):
        return Path(self.state_dir) / "tabs.json"

    def _write_state(self, tabs: dict):
        self._state_path().write_text(json.dumps({"tabs": tabs}))

    def _fake_herdr(self, renames: list):
        def fake(*args, **kwargs):
            cmd = tuple(args)
            if cmd == ("tab", "list"):
                return {
                    "result": {
                        "tabs": [{"tab_id": "w1:t1", "label": "nvim", "pane_count": 1}]
                    }
                }
            if cmd == ("pane", "get", "w1:p1"):
                return {"result": {"pane": {"pane_id": "w1:p1", "tab_id": "w1:t1"}}}
            if cmd == ("pane", "layout", "--pane", "w1:p1"):
                return {"result": {"layout": {"focused_pane_id": "w1:p1"}}}
            if cmd == ("pane", "process-info", "--pane", "w1:p1"):
                return {
                    "result": {
                        "process_info": {
                            "foreground_processes": [
                                {
                                    "name": "zsh",
                                    "cwd": str(Path.home() / "work" / "dotfiles"),
                                }
                            ]
                        }
                    }
                }
            if cmd[:2] == ("tab", "rename"):
                renames.append(cmd)
                return {"result": {"ok": True}}
            raise AssertionError(f"unexpected herdr call: {cmd}")

        return fake

    def test_env_pane_and_tab_renames_and_marks_checked(self):
        """HERDR_PANE_ID + HERDR_TAB_ID set → rename + last_checked recorded."""
        renames = []
        # Plugin previously named this tab "nvim" (nvim was the foreground
        # process); the state record is what makes the rename allowed.
        self._write_state({"w1:t1": {"plugin_label": "nvim"}})
        env = dict(self.env, HERDR_PANE_ID="w1:p1", HERDR_TAB_ID="w1:t1")
        with patch.dict("os.environ", env, clear=False):
            with patch("tabname._herdr", side_effect=self._fake_herdr(renames)):
                tabname._handle_pane_updated()

        self.assertEqual(renames, [("tab", "rename", "w1:t1", "~/work/dotfiles")])
        entry = json.loads(self._state_path().read_text())["tabs"]["w1:t1"]
        self.assertEqual(entry["plugin_label"], "~/work/dotfiles")
        self.assertIn("last_checked", entry)

    def test_event_json_fallback_resolves_pane_and_tab(self):
        """No env pane/tab → pane_id from event JSON, tab_id via pane get."""
        renames = []
        self._write_state({"w1:t1": {"plugin_label": "nvim"}})
        payload = json.dumps(
            {"event": "pane.updated", "data": {"pane": {"pane_id": "w1:p1"}}}
        )
        env = dict(self.env, HERDR_PLUGIN_EVENT_JSON=payload)
        with patch.dict("os.environ", env, clear=False):
            with patch("tabname._herdr", side_effect=self._fake_herdr(renames)):
                tabname._handle_pane_updated()

        self.assertEqual(renames, [("tab", "rename", "w1:t1", "~/work/dotfiles")])

    def test_recently_checked_tab_is_debounced(self):
        """last_checked within DEBOUNCE_SECONDS → no CLI calls at all."""
        self._write_state(
            {"w1:t1": {"plugin_label": "nvim", "last_checked": time.time()}}
        )

        def bomb(*args, **kwargs):
            raise AssertionError("debounced event must not call herdr")

        with patch.dict(
            "os.environ",
            dict(self.env, HERDR_PANE_ID="w1:p1", HERDR_TAB_ID="w1:t1"),
            clear=False,
        ):
            with patch("tabname._herdr", side_effect=bomb):
                tabname._handle_pane_updated()

    def test_stale_checked_tab_is_not_debounced(self):
        """last_checked older than DEBOUNCE_SECONDS → renamed again."""
        renames = []
        self._write_state(
            {
                "w1:t1": {
                    "plugin_label": "nvim",
                    "last_checked": time.time() - tabname.DEBOUNCE_SECONDS - 5,
                }
            }
        )
        with patch.dict(
            "os.environ",
            dict(self.env, HERDR_PANE_ID="w1:p1", HERDR_TAB_ID="w1:t1"),
            clear=False,
        ):
            with patch("tabname._herdr", side_effect=self._fake_herdr(renames)):
                tabname._handle_pane_updated()

        self.assertEqual(renames, [("tab", "rename", "w1:t1", "~/work/dotfiles")])

    def test_background_pane_title_change_ignored(self):
        """Updated pane is not the tab's focused pane → no rename."""
        renames = []
        self._write_state({"w1:t1": {"plugin_label": "nvim"}})

        def fake(*args, **kwargs):
            cmd = tuple(args)
            if cmd == ("pane", "layout", "--pane", "w1:p1"):
                return {"result": {"layout": {"focused_pane_id": "w1:p2"}}}
            raise AssertionError(f"background title change must stop at layout: {cmd}")

        with patch.dict(
            "os.environ",
            dict(self.env, HERDR_PANE_ID="w1:p1", HERDR_TAB_ID="w1:t1"),
            clear=False,
        ):
            with patch("tabname._herdr", side_effect=fake):
                tabname._handle_pane_updated()

        self.assertEqual(renames, [])

    def test_user_renamed_tab_not_touched(self):
        """User-named tab (label not numeric, not ours) → no rename, state popped."""
        renames = []
        self._write_state({"w1:t1": {"plugin_label": "old-auto-name"}})

        def fake(*args, **kwargs):
            cmd = tuple(args)
            if cmd == ("tab", "list"):
                return {
                    "result": {
                        "tabs": [
                            {"tab_id": "w1:t1", "label": "my-name", "pane_count": 1}
                        ]
                    }
                }
            if cmd == ("pane", "get", "w1:p1"):
                return {"result": {"pane": {"pane_id": "w1:p1", "tab_id": "w1:t1"}}}
            if cmd == ("pane", "layout", "--pane", "w1:p1"):
                return {"result": {"layout": {"focused_pane_id": "w1:p1"}}}
            if cmd == ("pane", "process-info", "--pane", "w1:p1"):
                return {
                    "result": {
                        "process_info": {
                            "foreground_processes": [
                                {
                                    "name": "zsh",
                                    "cwd": str(Path.home() / "work" / "dotfiles"),
                                }
                            ]
                        }
                    }
                }
            raise AssertionError(f"unexpected herdr call: {cmd}")

        with patch.dict(
            "os.environ",
            dict(self.env, HERDR_PANE_ID="w1:p1", HERDR_TAB_ID="w1:t1"),
            clear=False,
        ):
            with patch("tabname._herdr", side_effect=fake):
                tabname._handle_pane_updated()

        self.assertEqual(renames, [])
        self.assertEqual(json.loads(self._state_path().read_text())["tabs"], {})

    def test_missing_pane_id_returns_silently(self):
        """No pane_id anywhere → no herdr calls."""

        def bomb(*args, **kwargs):
            raise AssertionError("must not call herdr without a pane_id")

        with patch.dict("os.environ", self.env, clear=False):
            with patch("tabname._herdr", side_effect=bomb):
                tabname._handle_pane_updated()


class TestDebounce(unittest.TestCase):
    """_is_debounced() pure helper."""

    def test_no_entry_not_debounced(self):
        self.assertFalse(tabname._is_debounced({"tabs": {}}, "t1"))

    def test_no_last_checked_not_debounced(self):
        state = {"tabs": {"t1": {"plugin_label": "vim"}}}
        self.assertFalse(tabname._is_debounced(state, "t1"))

    def test_recent_last_checked_debounced(self):
        state = {"tabs": {"t1": {"last_checked": time.time()}}}
        self.assertTrue(tabname._is_debounced(state, "t1"))

    def test_old_last_checked_not_debounced(self):
        state = {"tabs": {"t1": {"last_checked": time.time() - 60}}}
        self.assertFalse(tabname._is_debounced(state, "t1"))


if __name__ == "__main__":
    unittest.main()
