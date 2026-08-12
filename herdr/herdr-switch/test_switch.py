#!/usr/bin/env python3
"""
Tests for switch.py — herdr-switch Python rewrite.

Usage: uv run python test_switch.py
"""

import json

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import switch


HOME = "/Users/x"


# ---- Slice 1: redact -----------------------------------------------------


class TestRedact(unittest.TestCase):
    """redact_path / redact_text — home → ~, byte-identical to old jq."""

    def test_redact_path_home_itself(self):
        self.assertEqual(switch.redact_path(HOME, HOME), "~")

    def test_redact_path_under_home(self):
        self.assertEqual(
            switch.redact_path(f"{HOME}/work/dotfiles", HOME), "~/work/dotfiles"
        )

    def test_redact_path_deep_nested(self):
        self.assertEqual(switch.redact_path(f"{HOME}/a/b/c", HOME), "~/a/b/c")

    def test_redact_path_outside_home_unchanged(self):
        self.assertEqual(switch.redact_path("/opt/app", HOME), "/opt/app")

    def test_redact_path_home_like_prefix_not_collapsed(self):
        """/Users/xy must not collapse when home is /Users/x."""
        self.assertEqual(switch.redact_path("/Users/xy/work", HOME), "/Users/xy/work")

    def test_redact_path_empty(self):
        self.assertEqual(switch.redact_path("", HOME), "")

    def test_redact_text_middle(self):
        self.assertEqual(
            switch.redact_text(f"edit {HOME}/work/a.md with vim", HOME),
            "edit ~/work/a.md with vim",
        )

    def test_redact_text_at_end(self):
        self.assertEqual(
            switch.redact_text(f"cwd {HOME}", HOME),
            "cwd ~",
        )

    def test_redact_text_no_home(self):
        self.assertEqual(
            switch.redact_text("/var/log/messages", HOME),
            "/var/log/messages",
        )

    def test_redact_text_home_prefix_partial_word_not_replaced(self):
        """home followed by a non-slash char must stay (jq regex (?=/|$))."""
        self.assertEqual(
            switch.redact_text(f"{HOME}xy/thing", HOME),
            f"{HOME}xy/thing",
        )

    def test_redact_text_multiple_occurrences(self):
        self.assertEqual(
            switch.redact_text(f"{HOME}/a {HOME}/b", HOME),
            "~/a ~/b",
        )


# ---- Slice 2: tab display label ------------------------------------------


class TestTabDisplayLabel(unittest.TestCase):
    """tab_display_label — numeric labels get a t prefix."""

    def test_numeric_becomes_t_label(self):
        self.assertEqual(switch.tab_display_label("1"), "t1")

    def test_multi_digit_numeric(self):
        self.assertEqual(switch.tab_display_label("12"), "t12")

    def test_named_label_unchanged(self):
        self.assertEqual(switch.tab_display_label("markdown"), "markdown")

    def test_empty_label_unchanged(self):
        self.assertEqual(switch.tab_display_label(""), "")

    def test_mixed_label_unchanged(self):
        self.assertEqual(switch.tab_display_label("t1"), "t1")


# ---- Slice 3: recency sorting -------------------------------------------


def _agent(id):
    return {"workspace_id": id, "focused": False}


class TestRecencySort(unittest.TestCase):
    """Most recently used at the bottom, focused strictly last."""

    def test_unrecorded_rows_keep_original_order(self):
        """No recency record → original order (stable sort, rank -999999)."""
        agents = [_agent("wA"), _agent("wB"), _agent("wC")]
        self.assertEqual(
            [a["workspace_id"] for a in switch.sorted_agents(agents, [])],
            ["wA", "wB", "wC"],
        )

    def test_recent_rows_at_bottom_reversed(self):
        """recent [wB, wA] → wB (most recent) is the last row, wA above it."""
        agents = [_agent("wA"), _agent("wB"), _agent("wC")]
        self.assertEqual(
            [a["workspace_id"] for a in switch.sorted_agents(agents, ["wB", "wA"])],
            ["wC", "wA", "wB"],
        )

    def test_focused_strictly_last(self):
        """Focused row ranks 1 → always the very bottom, even when in recent."""
        agents = [
            {"workspace_id": "wA", "focused": False},
            {"workspace_id": "wB", "focused": True},
            {"workspace_id": "wC", "focused": False},
        ]
        self.assertEqual(
            [a["workspace_id"] for a in switch.sorted_agents(agents, ["wB", "wA"])],
            ["wC", "wA", "wB"],
        )

    def test_focused_last_even_when_state_diverges(self):
        """recent[0] ≠ focused → the focused one still parks at the bottom."""
        agents = [
            {"workspace_id": "wA", "focused": False},
            {"workspace_id": "wB", "focused": True},
        ]
        self.assertEqual(
            [a["workspace_id"] for a in switch.sorted_agents(agents, ["wA"])],
            ["wA", "wB"],
        )

    def test_same_workspace_agents_keep_original_order(self):
        """Two agents in one workspace share the rank → stable order kept."""
        a1 = {**{"workspace_id": "wA"}, "agent": "first"}
        a2 = {**{"workspace_id": "wA"}, "agent": "second"}
        agents = [a1, a2]
        self.assertEqual(
            [a["agent"] for a in switch.sorted_agents(agents, ["wA"])],
            ["first", "second"],
        )

    def test_spaces_sorted_same_way(self):
        workspaces = [
            {"workspace_id": "wA", "focused": False},
            {"workspace_id": "wB", "focused": False},
            {"workspace_id": "wC", "focused": True},
        ]
        self.assertEqual(
            [w["workspace_id"] for w in switch.sorted_workspaces(workspaces, ["wB"])],
            ["wA", "wB", "wC"],
        )


# ---- Slice 4-6: row builders + build_lines -------------------------------


def _agent_fixture(**over):
    base = {
        "agent": "pi",
        "agent_status": "idle",
        "cwd": f"{HOME}/work/pi-kit",
        "focused": False,
        "pane_id": "w1:p3",
        "tab_id": "w1:t1",
        "terminal_title_stripped": "π - pi-kit",
        "workspace_id": "w1",
    }
    base.update(over)
    return base


def _space_fixture(**over):
    base = {
        "workspace_id": "w1",
        "label": "pi-kit",
        "pane_count": 2,
        "focused": False,
    }
    base.update(over)
    return base


WSMAP = {"w1": {"label": "pi-kit", "pane_count": 2}}
TABMAP = {"w1:t1": "t1"}


class TestAgentRow(unittest.TestCase):
    def test_working_focused_agent_full_fields(self):
        row = switch.agent_row(
            _agent_fixture(agent_status="working", focused=True),
            WSMAP,
            TABMAP,
            HOME,
        )
        self.assertEqual(row[switch.F_KIND], "agent")
        self.assertEqual(row[switch.F_TARGET], "w1:p3")
        self.assertEqual(row[switch.F_STATUS], "working (聚焦)")
        self.assertEqual(row[switch.F_WS], "pi-kit")
        self.assertEqual(row[switch.F_CWD], "~/work/pi-kit")
        self.assertEqual(row[switch.F_TITLE], "π - pi-kit")
        self.assertEqual(row[switch.F_NAME], "pi")
        self.assertEqual(row[switch.F_RAW], "working")
        self.assertEqual(row[switch.F_RUNNING], "1")
        self.assertEqual(
            row[switch.F_DISPLAY],
            f"{switch.DOT_WORKING} agent  pi @ pi-kit · t1  ~/work/pi-kit  ◀ 聚焦",
        )

    def test_status_dots(self):
        self.assertTrue(
            switch.agent_row(
                _agent_fixture(agent_status="working"), WSMAP, TABMAP, HOME
            )[0].startswith(switch.DOT_WORKING)
        )
        self.assertTrue(
            switch.agent_row(
                _agent_fixture(agent_status="blocked"), WSMAP, TABMAP, HOME
            )[0].startswith(switch.DOT_BLOCKED)
        )
        self.assertTrue(
            switch.agent_row(_agent_fixture(agent_status="done"), WSMAP, TABMAP, HOME)[
                0
            ].startswith(switch.DOT_DONE)
        )
        self.assertTrue(
            switch.agent_row(_agent_fixture(agent_status="idle"), WSMAP, TABMAP, HOME)[
                0
            ].startswith(switch.DOT_OTHER)
        )

    def test_running_flag(self):
        for status, expected in (
            ("working", "1"),
            ("blocked", "1"),
            ("done", "0"),
            ("idle", "0"),
        ):
            with self.subTest(status=status):
                row = switch.agent_row(
                    _agent_fixture(agent_status=status), WSMAP, TABMAP, HOME
                )
                self.assertEqual(row[switch.F_RUNNING], expected)

    def test_no_focus_marker_when_not_focused(self):
        row = switch.agent_row(_agent_fixture(), WSMAP, TABMAP, HOME)
        self.assertNotIn("聚焦", row[switch.F_DISPLAY])
        self.assertEqual(row[switch.F_STATUS], "idle")

    def test_missing_workspace_label_falls_back_to_id(self):
        row = switch.agent_row(_agent_fixture(workspace_id="w9"), {}, TABMAP, HOME)
        self.assertEqual(row[switch.F_WS], "w9")
        self.assertIn("w9", row[switch.F_DISPLAY])

    def test_missing_tab_yields_empty_tab_slot(self):
        row = switch.agent_row(_agent_fixture(tab_id="w9:t9"), WSMAP, {}, HOME)
        self.assertIn("pi @ pi-kit ·   ~/work/pi-kit", row[switch.F_DISPLAY])

    def test_name_falls_back_to_agent_key(self):
        row = switch.agent_row(_agent_fixture(name="my-label"), WSMAP, TABMAP, HOME)
        self.assertEqual(row[switch.F_NAME], "my-label")

    def test_title_redacted_anywhere(self):
        row = switch.agent_row(
            _agent_fixture(terminal_title_stripped=f"vim {HOME}/work/a.md"),
            WSMAP,
            TABMAP,
            HOME,
        )
        self.assertEqual(row[switch.F_TITLE], "vim ~/work/a.md")


class TestSpaceRow(unittest.TestCase):
    def test_plain_space(self):
        row = switch.space_row(_space_fixture(), 0)
        self.assertEqual(row[switch.F_DISPLAY], f"{switch.BOX_OTHER} space  pi-kit")
        self.assertEqual(row[switch.F_KIND], "space")
        self.assertEqual(row[switch.F_TARGET], "w1")
        self.assertEqual(row[switch.F_STATUS], "-")
        self.assertEqual(row[switch.F_WS], "pi-kit")
        self.assertEqual(row[switch.F_CWD], "")
        self.assertEqual(row[switch.F_TITLE], "2 panes")
        self.assertEqual(row[switch.F_NAME], "pi-kit")
        self.assertEqual(row[switch.F_RAW], "-")
        self.assertEqual(row[switch.F_RUNNING], "0")

    def test_running_space_yellow_icon_and_count(self):
        row = switch.space_row(_space_fixture(), 2)
        self.assertTrue(row[switch.F_DISPLAY].startswith(switch.BOX_RUNNING))
        self.assertEqual(row[switch.F_RUNNING], "2")

    def test_current_space_markers(self):
        row = switch.space_row(_space_fixture(focused=True), 0)
        self.assertEqual(
            row[switch.F_DISPLAY], f"{switch.BOX_OTHER} space  pi-kit  ◀ 当前"
        )
        self.assertEqual(row[switch.F_STATUS], "当前")
        self.assertEqual(row[switch.F_RAW], "current")


class TestBuildLines(unittest.TestCase):
    def test_agents_then_spaces_with_trailing_newline(self):
        agents = [
            _agent_fixture(workspace_id="w2", agent="codex", cwd=f"{HOME}/other"),
            _agent_fixture(),
        ]
        workspaces = [
            _space_fixture(),
            _space_fixture(workspace_id="w2", label="other", pane_count=1),
        ]
        tabs = [{"tab_id": "w1:t1", "label": "1"}]
        recent = ["w2"]
        out = switch.build_lines(agents, workspaces, tabs, recent, HOME)

        agent_lines = [line for line in out.splitlines() if "\tagent\t" in line]
        space_lines = [line for line in out.splitlines() if "\tspace\t" in line]
        self.assertEqual(len(agent_lines), 2)
        self.assertEqual(len(space_lines), 2)
        self.assertTrue(out.endswith("\n"))
        # Agents block comes first, spaces after.
        self.assertLess(out.index("\tagent\t"), out.index("\tspace\t"))
        # Recency: w2 (recent[0]) parks at the bottom of the agent block.
        self.assertIn("codex", agent_lines[1])
        self.assertIn("pi @ pi-kit", agent_lines[0])

    def test_empty_inputs_yield_empty_string(self):
        self.assertEqual(switch.build_lines([], [], [], [], HOME), "")


# ---- Slice 7-9: close_plan / cursor / fzf output --------------------------


class TestClosePlan(unittest.TestCase):
    """Confirmation matrix: only dangerous closes ask for y/N."""

    def test_agent_working_confirms(self):
        need, msg = switch.close_plan("agent", "working", "0", "pi")
        self.assertTrue(need)
        self.assertEqual(msg, "close agent pi? (状态: working)")

    def test_agent_blocked_confirms(self):
        need, msg = switch.close_plan("agent", "blocked", "0", "pi")
        self.assertTrue(need)
        self.assertEqual(msg, "close agent pi? (状态: blocked)")

    def test_agent_idle_no_confirm(self):
        need, msg = switch.close_plan("agent", "idle", "0", "pi")
        self.assertFalse(need)
        self.assertIsNone(msg)

    def test_agent_done_no_confirm(self):
        need, msg = switch.close_plan("agent", "done", "0", "pi")
        self.assertFalse(need)
        self.assertIsNone(msg)

    def test_current_space_always_confirms(self):
        need, msg = switch.close_plan("space", "current", "0", "pi-kit")
        self.assertTrue(need)
        self.assertEqual(msg, "close space pi-kit? (当前 space)")

    def test_space_with_running_agents_confirms(self):
        need, msg = switch.close_plan("space", "-", "3", "pi-kit")
        self.assertTrue(need)
        self.assertEqual(msg, "close space pi-kit? (3 个 agent 运行中)")

    def test_clean_space_no_confirm(self):
        need, msg = switch.close_plan("space", "-", "0", "pi-kit")
        self.assertFalse(need)
        self.assertIsNone(msg)

    def test_non_numeric_running_treated_as_zero(self):
        need, msg = switch.close_plan("space", "-", "abc", "pi-kit")
        self.assertFalse(need)
        self.assertIsNone(msg)


class TestNextCursorIndex(unittest.TestCase):
    def test_closed_parks_above_deleted_row(self):
        self.assertEqual(switch.next_cursor_index(closed=True, idx=5), 4)

    def test_closed_first_row_clamped_to_one(self):
        self.assertEqual(switch.next_cursor_index(closed=True, idx=1), 1)

    def test_not_closed_keeps_row(self):
        self.assertEqual(switch.next_cursor_index(closed=False, idx=7), 7)


class TestParseFzfOutput(unittest.TestCase):
    def test_enter_has_empty_key(self):
        self.assertEqual(
            switch.parse_fzf_output("my query\n\nw1\tagent\tp1\n"),
            ("my query", "", "w1\tagent\tp1"),
        )

    def test_ctrl_x_key(self):
        self.assertEqual(
            switch.parse_fzf_output("q\nctrl-x\nw1\tspace\tw1\n"),
            ("q", "ctrl-x", "w1\tspace\tw1"),
        )

    def test_alt_enter_key(self):
        self.assertEqual(
            switch.parse_fzf_output("q\nalt-enter\nw1\tagent\tp1\n"),
            ("q", "alt-enter", "w1\tagent\tp1"),
        )

    def test_empty_output(self):
        self.assertEqual(switch.parse_fzf_output(""), ("", "", ""))

    def test_no_trailing_newline(self):
        self.assertEqual(
            switch.parse_fzf_output("q\nctrl-x\nw1"), ("q", "ctrl-x", "w1")
        )


# ---- Slice 10-13: recency / record / toggle / preview ---------------------


class TestRecencyUpdate(unittest.TestCase):
    def test_new_goes_front(self):
        self.assertEqual(switch.recency_update(["wB", "wA"], "wC"), ["wC", "wB", "wA"])

    def test_dedupes_existing(self):
        self.assertEqual(
            switch.recency_update(["wB", "wA", "wC"], "wB"), ["wB", "wA", "wC"]
        )

    def test_empty_input(self):
        self.assertEqual(switch.recency_update([], "wA"), ["wA"])

    def test_capped_at_max_recent(self):
        recent = [f"w{i}" for i in range(switch.MAX_RECENT)]
        out = switch.recency_update(recent, "wNew")
        self.assertEqual(len(out), switch.MAX_RECENT)
        self.assertEqual(out[0], "wNew")
        self.assertNotIn("w19", out)


class TestEventWorkspaceId(unittest.TestCase):
    def test_nested_data_workspace_id(self):
        event = json.dumps(
            {
                "event": "workspace.focused",
                "data": {"type": "workspace_focused", "workspace_id": "wA"},
            }
        )
        self.assertEqual(switch.parse_event_workspace_id(event), "wA")

    def test_top_level_fallback(self):
        self.assertEqual(
            switch.parse_event_workspace_id('{"workspace_id": "wB"}'), "wB"
        )

    def test_missing_returns_empty(self):
        self.assertEqual(switch.parse_event_workspace_id('{"event": "x"}'), "")
        self.assertEqual(switch.parse_event_workspace_id(""), "")
        self.assertEqual(switch.parse_event_workspace_id("not json"), "")


class TestNormalizeState(unittest.TestCase):
    def test_missing_state_defaults(self):
        state = switch.normalize_state(None)
        self.assertEqual(state, {"current": None, "previous": None, "recent": []})

    def test_corrupt_recent_degrades_to_empty(self):
        state = switch.normalize_state({"current": "wA", "recent": {"not": "array"}})
        self.assertEqual(state["recent"], [])

    def test_old_format_without_recent(self):
        state = switch.normalize_state({"current": "wA", "previous": "wB"})
        self.assertEqual(state["recent"], [])
        self.assertEqual(state["current"], "wA")
        self.assertEqual(state["previous"], "wB")


class TestRecordState(unittest.TestCase):
    def test_first_record(self):
        out = switch.record_state("wA", switch.normalize_state(None))
        self.assertEqual(out, {"current": "wA", "previous": None, "recent": ["wA"]})

    def test_same_workspace_ignored(self):
        old = {"current": "wA", "previous": "wB", "recent": ["wA", "wB"]}
        self.assertIsNone(switch.record_state("wA", old))

    def test_new_workspace_shifts_previous(self):
        old = {"current": "wA", "previous": "wB", "recent": ["wA", "wB"]}
        self.assertEqual(
            switch.record_state("wC", old),
            {"current": "wC", "previous": "wA", "recent": ["wC", "wA", "wB"]},
        )

    def test_recent_dedupes_and_caps(self):
        old = {"current": "wA", "previous": None, "recent": ["wB", "wA"]}
        out = switch.record_state("wB", old)
        assert out is not None
        self.assertEqual(out["recent"], ["wB", "wA"])

    def test_empty_previous_becomes_null(self):
        old = {"current": "wA", "previous": "", "recent": ["wA"]}
        self.assertIsNone(switch.record_state("wA", old))  # same ws → ignored anyway
        out = switch.record_state("wB", old)
        assert out is not None
        self.assertEqual(out["previous"], "wA")


class TestToggleState(unittest.TestCase):
    def test_success_swaps_current_previous(self):
        old = {"current": "wA", "previous": "wB", "recent": ["wA", "wB"]}
        self.assertEqual(
            switch.toggle_state(old, "wB", ok=True),
            {"current": "wB", "previous": "wA", "recent": ["wB", "wA"]},
        )

    def test_success_moves_target_to_recent_front(self):
        old = {"current": "wA", "previous": "wB", "recent": ["wA", "wB"]}
        out = switch.toggle_state(old, "wB", ok=True)
        self.assertEqual(out["recent"][0], "wB")

    def test_failure_drops_previous_keeps_current_and_recent(self):
        old = {"current": "wA", "previous": "wB", "recent": ["wA", "wB"]}
        self.assertEqual(
            switch.toggle_state(old, "wB", ok=False),
            {"current": "wA", "previous": None, "recent": ["wA", "wB"]},
        )

    def test_failure_ignores_target_value(self):
        old = {"current": "wA", "previous": "wB", "recent": ["wA", "wB"]}
        self.assertEqual(
            switch.toggle_state(old, "whatever", ok=False),
            {"current": "wA", "previous": None, "recent": ["wA", "wB"]},
        )


class TestSubToggle(unittest.TestCase):
    """sub_toggle: the silent no-op guard lives here, not in toggle_state."""

    def setUp(self):
        self.state_dir = Path(tempfile.mkdtemp(prefix="switch-toggle-"))
        self.env = {"HERDR_PLUGIN_STATE_DIR": str(self.state_dir), "HOME": HOME}

    def _state_file(self):
        return self.state_dir / "prev-space.json"

    def _fake_herdr(self, log, focus_ok=True):
        def fake(*args, **kwargs):
            log.append(args)
            if args[:2] == ("workspace", "focus"):
                return {"result": {"ok": True}} if focus_ok else None
            if args[:2] == ("workspace", "get"):
                return {"result": {"workspace": {"label": "common_biz"}}}
            if args[:2] == ("notification", "show"):
                return {"result": {"ok": True}}
            return None

        return fake

    def test_no_state_file_is_silent(self):
        log = []
        with patch.dict("os.environ", self.env, clear=False):
            with patch("switch.herdr", side_effect=self._fake_herdr(log)):
                switch.sub_toggle()
        self.assertEqual(log, [])
        self.assertFalse(self._state_file().exists())

    def test_no_previous_is_silent(self):
        self._state_file().write_text(
            json.dumps({"current": "wA", "previous": None, "recent": ["wA"]})
        )
        log = []
        with patch.dict("os.environ", self.env, clear=False):
            with patch("switch.herdr", side_effect=self._fake_herdr(log)):
                switch.sub_toggle()
        self.assertEqual(log, [])
        # file untouched
        self.assertEqual(json.loads(self._state_file().read_text())["current"], "wA")

    def test_success_focuses_and_swaps_state(self):
        self._state_file().write_text(
            json.dumps({"current": "wA", "previous": "wB", "recent": ["wA", "wB"]})
        )
        log = []
        with patch.dict("os.environ", self.env, clear=False):
            with patch("switch.herdr", side_effect=self._fake_herdr(log)):
                switch.sub_toggle()
        self.assertIn(("workspace", "focus", "wB"), log)
        self.assertIn(("notification", "show"), [a[:2] for a in log])
        state = json.loads(self._state_file().read_text())
        self.assertEqual(state["current"], "wB")
        self.assertEqual(state["previous"], "wA")
        self.assertEqual(state["recent"], ["wB", "wA"])

    def test_failure_drops_previous(self):
        self._state_file().write_text(
            json.dumps({"current": "wA", "previous": "wB", "recent": ["wA", "wB"]})
        )
        log = []
        with patch.dict("os.environ", self.env, clear=False):
            with patch(
                "switch.herdr", side_effect=self._fake_herdr(log, focus_ok=False)
            ):
                switch.sub_toggle()
        state = json.loads(self._state_file().read_text())
        self.assertEqual(state["current"], "wA")
        self.assertIsNone(state["previous"])
        self.assertEqual(state["recent"], ["wA", "wB"])
        self.assertNotIn("notification", [a[0] for a in log])


class TestPreviewText(unittest.TestCase):
    def test_agent_block_exact(self):
        line = "\t".join(
            [
                "display",
                "agent",
                "w1:p3",
                "idle",
                "pi-kit",
                "~/work/pi-kit",
                "π - pi-kit",
                "pi",
                "idle",
                "0",
            ]
        )
        expected = (
            f"{switch.COLOR_BOLD}pi{switch.RESET}\n"
            "\n"
            "状态:   idle\n"
            "space:  pi-kit\n"
            "cwd:    ~/work/pi-kit\n"
            "终端:   π - pi-kit\n"
            "pane:   w1:p3\n"
        )
        self.assertEqual(switch.preview_text(line), expected)

    def test_space_block_exact(self):
        line = "\t".join(
            [
                "display",
                "space",
                "w1",
                "当前",
                "pi-kit",
                "",
                "2 panes",
                "pi-kit",
                "current",
                "1",
            ]
        )
        expected = (
            f"{switch.COLOR_BOLD}pi-kit{switch.RESET}\n"
            "\n"
            "id:     w1\n"
            "panes:  2 panes\n"
            "状态:   当前\n"
        )
        self.assertEqual(switch.preview_text(line), expected)

    def test_empty_line_renders_nothing(self):
        self.assertEqual(switch.preview_text(""), "")


# ---- Slice 14-15: fetch_data validation + main loop ------------------------


def _agents_json():
    return {"result": {"agents": [_agent_fixture()]}}


def _ws_json():
    return {"result": {"workspaces": [_space_fixture()]}}


def _tabs_json():
    return {"result": {"tabs": [{"tab_id": "w1:t1", "label": "1", "focused": False}]}}


class TestHeaderText(unittest.TestCase):
    def test_header_includes_current_space_and_tab(self):
        self.assertEqual(
            switch.header_text("pi-kit", "t1"),
            "当前 space: pi-kit · 当前 tab: t1    enter=focus · alt+enter=attach · ctrl+x=close · esc=退出 · 最近使用在底部",
        )


class TestFetchData(unittest.TestCase):
    def test_valid_data_parsed(self):
        def fake_herdr(*args, **kwargs):
            if args == ("agent", "list"):
                return _agents_json()
            if args == ("workspace", "list"):
                return _ws_json()
            if args == ("tab", "list"):
                return _tabs_json()
            return None

        with patch("switch.herdr", side_effect=fake_herdr):
            agents, ws, tabs, cur_ws, cur_tab = switch.fetch_data()
        self.assertEqual(len(agents), 1)
        self.assertEqual(len(ws), 1)
        self.assertEqual(len(tabs), 1)
        self.assertEqual(cur_ws, "?")
        self.assertEqual(cur_tab, "?")

    def test_focused_workspace_and_tab_extracted(self):
        def fake_herdr(*args, **kwargs):
            if args == ("agent", "list"):
                return {"result": {"agents": []}}
            if args == ("workspace", "list"):
                return {"result": {"workspaces": [_space_fixture(focused=True)]}}
            if args == ("tab", "list"):
                return {
                    "result": {
                        "tabs": [{"tab_id": "w1:t1", "label": "1", "focused": True}]
                    }
                }
            return None

        with patch("switch.herdr", side_effect=fake_herdr):
            _, _, _, cur_ws, cur_tab = switch.fetch_data()
        self.assertEqual(cur_ws, "pi-kit")
        self.assertEqual(cur_tab, "t1")

    def test_agent_list_cli_failure(self):
        with patch("switch.herdr", return_value=None):
            with self.assertRaises(switch.FetchError) as ctx:
                switch.fetch_data()
        self.assertEqual(str(ctx.exception), "herdr agent list 失败(herdr 在运行吗?)")

    def test_workspace_list_cli_failure(self):
        def fake_herdr(*args, **kwargs):
            if args == ("agent", "list"):
                return _agents_json()
            return None

        with patch("switch.herdr", side_effect=fake_herdr):
            with self.assertRaises(switch.FetchError) as ctx:
                switch.fetch_data()
        self.assertEqual(str(ctx.exception), "herdr workspace list 失败")

    def test_tab_list_cli_failure(self):
        def fake_herdr(*args, **kwargs):
            if args == ("agent", "list"):
                return _agents_json()
            if args == ("workspace", "list"):
                return _ws_json()
            return None

        with patch("switch.herdr", side_effect=fake_herdr):
            with self.assertRaises(switch.FetchError) as ctx:
                switch.fetch_data()
        self.assertEqual(str(ctx.exception), "herdr tab list 失败")

    def test_unparseable_agent_payload(self):
        def fake_herdr(*args, **kwargs):
            if args == ("agent", "list"):
                return {"result": {}}
            if args == ("workspace", "list"):
                return _ws_json()
            if args == ("tab", "list"):
                return _tabs_json()
            return None

        with patch("switch.herdr", side_effect=fake_herdr):
            with self.assertRaises(switch.FetchError) as ctx:
                switch.fetch_data()
        self.assertEqual(str(ctx.exception), "agent list 返回了无法解析的数据")

    def test_empty_agent_list_is_valid(self):
        def fake_herdr(*args, **kwargs):
            if args == ("agent", "list"):
                return {"result": {"agents": []}}
            if args == ("workspace", "list"):
                return _ws_json()
            if args == ("tab", "list"):
                return _tabs_json()
            return None

        with patch("switch.herdr", side_effect=fake_herdr):
            agents, _, _, _, _ = switch.fetch_data()
        self.assertEqual(agents, [])


class TestPickerLoop(unittest.TestCase):
    """Main loop with mocked herdr + fzf: observable behavior only."""

    @staticmethod
    def _agent_line():
        row = switch.agent_row(_agent_fixture(), WSMAP, TABMAP, HOME)
        return "\t".join(row)

    @staticmethod
    def _space_line():
        row = switch.space_row(_space_fixture(), 0)
        return "\t".join(row)

    def _herdr_fake(self, focus_ok=True, close_ok=True):
        class FakeHerdr:
            """Callable fake herdr with an inspectable call log."""

            def __init__(self):
                self.log: list[tuple] = []

            def __call__(self, *args, **kwargs):
                self.log.append(args)
                if args == ("agent", "list"):
                    return _agents_json()
                if args == ("workspace", "list"):
                    return _ws_json()
                if args == ("tab", "list"):
                    return _tabs_json()
                if args[:2] == ("agent", "focus") or args[:2] == ("workspace", "focus"):
                    return {"result": {"ok": True}} if focus_ok else None
                if args[:2] == ("agent", "attach"):
                    return {"result": {"ok": True}} if focus_ok else None
                if args[:2] == ("pane", "close") or args[:2] == ("workspace", "close"):
                    return {"result": {"ok": True}} if close_ok else None
                return None

        return FakeHerdr()

    def _run_picker(self, fzf_results, herdr_fake, filtered=None):
        import io
        import contextlib

        env = {
            "HERDR_PLUGIN_STATE_DIR": tempfile.mkdtemp(prefix="switch-test-"),
            "HOME": HOME,
        }
        line = self._agent_line()
        with patch.dict("os.environ", env, clear=False):
            with patch("switch.herdr", side_effect=herdr_fake):
                with patch("switch.run_fzf", side_effect=fzf_results) as rf:
                    with patch(
                        "switch.run_fzf_filter",
                        return_value=filtered if filtered is not None else [line],
                    ) as rff:
                        with patch("switch.warn", return_value=None) as w:
                            with patch("switch.fail", return_value=None):
                                with contextlib.redirect_stdout(io.StringIO()):
                                    try:
                                        switch.sub_picker()
                                    except SystemExit:
                                        pass  # esc → silent exit
        return rf, rff, w

    def test_enter_on_agent_focuses_and_breaks(self):
        herdr = self._herdr_fake()
        rf, _, _ = self._run_picker([(0, f"q\n\n{self._agent_line()}\n")], herdr)
        self.assertIn(("agent", "focus", "w1:p3"), herdr.log)
        self.assertEqual(rf.call_count, 1)

    def test_first_open_binds_start_last(self):
        herdr = self._herdr_fake()
        rf, _, _ = self._run_picker([(0, f"q\n\n{self._agent_line()}\n")], herdr)
        binds = rf.call_args.kwargs["binds"]
        self.assertTrue(binds.startswith("alt-enter:accept"))
        self.assertIn("start:last", binds)
        self.assertIn("load:last", binds)

    def test_esc_exits_silently(self):
        herdr = self._herdr_fake()
        with self.assertRaises(SystemExit) as ctx:
            with patch.dict(
                "os.environ",
                {"HERDR_PLUGIN_STATE_DIR": tempfile.mkdtemp(), "HOME": HOME},
                clear=False,
            ):
                with patch("switch.herdr", side_effect=herdr):
                    with patch("switch.run_fzf", return_value=(1, "")):
                        switch.sub_picker()
        self.assertEqual(ctx.exception.code, 0)
        self.assertNotIn("focus", "".join(str(a) for a in herdr.log))

    def test_ctrl_x_idle_agent_closes_without_confirm_and_continues(self):
        herdr = self._herdr_fake()
        line = self._agent_line()
        rf, rff, _ = self._run_picker(
            [(0, f"q\nctrl-x\n{line}\n"), (0, f"q\n\n{line}\n")], herdr
        )
        self.assertIn(("pane", "close", "w1:p3"), herdr.log)
        self.assertEqual(rf.call_count, 2)  # loop continued
        self.assertTrue(rff.called)  # idx computed via fzf --filter

    def test_ctrl_x_then_cursor_parks_above_deleted_row(self):
        herdr = self._herdr_fake()
        line = self._agent_line()
        rf, rff, _ = self._run_picker(
            [(0, f"q\nctrl-x\n{line}\n"), (0, f"q\n\n{line}\n")],
            herdr,
            filtered=["other-row", line],
        )
        # idx=2, closed → park on the row above (pos 1)
        binds = rf.call_args_list[1].kwargs["binds"]
        self.assertIn("start:pos(1)", binds)

    def test_alt_enter_on_space_warns_and_stays(self):
        herdr = self._herdr_fake()
        line = self._space_line()
        rf, _, w = self._run_picker(
            [(0, f"q\nalt-enter\n{line}\n"), (0, f"q\n\n{self._agent_line()}\n")], herdr
        )
        self.assertIn("alt+enter 只能用于 agent", str(w.call_args))
        self.assertNotIn(("agent", "attach"), herdr.log)

    def test_alt_enter_on_agent_attaches_and_breaks(self):
        herdr = self._herdr_fake()
        rf, _, _ = self._run_picker(
            [(0, f"q\nalt-enter\n{self._agent_line()}\n")], herdr
        )
        self.assertIn(("agent", "attach", "w1:p3", "--takeover"), herdr.log)
        self.assertEqual(rf.call_count, 1)

    def test_focus_failure_warns_and_stays(self):
        herdr = self._herdr_fake(focus_ok=False)
        line = self._agent_line()
        rf, _, w = self._run_picker(
            [(0, f"q\n\n{line}\n"), (0, f"q\n\n{line}\n"), (1, "")], herdr
        )
        self.assertIn("agent focus 失败", str(w.call_args))
        self.assertEqual(rf.call_count, 3)

    def test_close_failure_warns_and_keeps_cursor(self):
        herdr = self._herdr_fake(close_ok=False)
        line = self._agent_line()
        rf, rff, w = self._run_picker(
            [(0, f"q\nctrl-x\n{line}\n"), (0, f"q\n\n{line}\n")],
            herdr,
            filtered=["other-row", line],
        )
        self.assertIn("pane close 失败", str(w.call_args))
        binds = rf.call_args_list[1].kwargs["binds"]
        self.assertIn("pos(2)", binds)  # idx 2, not closed → same row kept


if __name__ == "__main__":
    unittest.main()
