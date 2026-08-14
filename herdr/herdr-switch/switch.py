#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
herdr-switch — search spaces/agents and jump (Python rewrite of the bash
scripts: picker.sh / preview.sh / record.sh / toggle.sh / open.sh).

Subcommands (see herdr-plugin.toml):
    picker   — main fzf picker loop (prefix+f)
    preview  — fzf preview renderer (reads the selected TSV line from argv)
    record   — workspace.focused event hook (maintains prev-space.json)
    toggle   — prefix+^ toggle between the two most recent spaces
    open     — open the picker popup pane

Layout: pure functions (value in / value out) on top, thin shell adapters
(herdr CLI, fzf, terminal keys) below, main() dispatches subcommands.
"""

import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from typing import NoReturn
from pathlib import Path

# ---- constants -----------------------------------------------------------

MAX_RECENT = 20
STATE_FILE_NAME = "prev-space.json"

# Tab-separated line layout (must stay compatible with preview.sh's fields):
#   1 display  2 kind  3 target  4 status  5 ws  6 cwd  7 title  8 name
#   9 raw  10 running
(
    F_DISPLAY,
    F_KIND,
    F_TARGET,
    F_STATUS,
    F_WS,
    F_CWD,
    F_TITLE,
    F_NAME,
    F_RAW,
    F_RUNNING,
) = range(10)

# ANSI status dots / markers (byte-identical to the old jq output).
DOT_WORKING = "\033[33m●\033[0m"
DOT_BLOCKED = "\033[31m●\033[0m"
DOT_DONE = "\033[34m●\033[0m"
DOT_OTHER = "\033[90m●\033[0m"
BOX_RUNNING = "\033[33m▣\033[0m"
BOX_OTHER = "\033[35m▣\033[0m"

COLOR_RED = "\033[31m"
COLOR_YELLOW = "\033[33m"
COLOR_GRAY = "\033[90m"
COLOR_BOLD = "\033[1m"
RESET = "\033[0m"

_HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")


# ---- pure: redaction ------------------------------------------------------


def redact_path(cwd: str, home: str) -> str:
    """Redact *cwd* for display: home → ~, home prefix → ~/..., else as-is."""
    if cwd == home:
        return "~"
    if cwd.startswith(home + os.sep):
        return "~" + cwd[len(home) :]
    return cwd


def redact_text(text: str, home: str) -> str:
    """Replace every home occurrence (followed by / or end) with ~ anywhere."""
    return re.sub(re.escape(home) + r"(?=/|$)", "~", text)


# ---- pure: tab label ------------------------------------------------------


def tab_display_label(label: str) -> str:
    """Unnamed tabs carry numeric labels; display them as t<N>."""
    if label.isdigit():
        return "t" + label
    return label


# ---- pure: recency sorting ------------------------------------------------


def recency_rank(workspace_id: str, recent: list, focused: bool) -> int:
    """Rank for ascending sort: focused parks last; recent rows follow their
    reversed recency order; never-recorded rows (all tied at -999999) keep
    their original order via Python's stable sort."""
    if focused:
        return 1
    try:
        idx = recent.index(workspace_id)
    except ValueError:
        return -999999
    return -idx


def sorted_agents(agents: list[dict], recent: list) -> list[dict]:
    return sorted(
        agents,
        key=lambda a: recency_rank(
            a.get("workspace_id", ""), recent, a.get("focused", False)
        ),
    )


def sorted_workspaces(workspaces: list[dict], recent: list) -> list[dict]:
    return sorted(
        workspaces,
        key=lambda w: recency_rank(
            w.get("workspace_id", ""), recent, w.get("focused", False)
        ),
    )


# ---- pure: row builders ---------------------------------------------------


def _status_dot(status: str) -> str:
    if status == "working":
        return DOT_WORKING
    if status == "blocked":
        return DOT_BLOCKED
    if status == "done":
        return DOT_DONE
    return DOT_OTHER


def _is_running(status: str) -> bool:
    return status == "working" or status == "blocked"


def branch_suffix(branch: str | None) -> str:
    """分支名 → '  (feat/x)'；空/None → ''。"""
    if not branch:
        return ""
    return f"  ({branch})"


def with_branch(display: str, branch: str | None) -> str:
    """display 末尾追加 branch_suffix(branch)。"""
    return display + branch_suffix(branch)


def agent_row(agent: dict, wsmap: dict, tabmap: dict, home: str) -> list[str]:
    """Build the 10 TSV fields for one agent row (old jq byte-equivalent)."""
    ws_label = wsmap.get(agent.get("workspace_id", ""), {}).get("label") or agent.get(
        "workspace_id", ""
    )
    tab = tabmap.get(agent.get("tab_id", ""), "")
    cwd_disp = redact_path(agent.get("cwd") or "", home)
    title_disp = redact_text(agent.get("terminal_title_stripped") or "", home)
    name = agent.get("name") or agent.get("agent") or ""
    status = agent.get("agent_status", "")
    focused = agent.get("focused", False)

    display = (
        _status_dot(status)
        + f" agent  {name} @ {ws_label} · {tab}  {cwd_disp}"
        + ("  ◀ 聚焦" if focused else "")
    )
    return [
        display,
        "agent",
        agent.get("pane_id", ""),
        status + (" (聚焦)" if focused else ""),
        ws_label,
        cwd_disp,
        title_disp,
        name,
        status,
        "1" if _is_running(status) else "0",
    ]


def space_row(space: dict, running: int) -> list[str]:
    """Build the 10 TSV fields for one workspace row."""
    label = space.get("label", "")
    focused = space.get("focused", False)
    display = (
        (BOX_RUNNING if running > 0 else BOX_OTHER)
        + f" space  {label}"
        + ("  ◀ 当前" if focused else "")
    )
    return [
        display,
        "space",
        space.get("workspace_id", ""),
        "当前" if focused else "-",
        label,
        "",
        f"{space.get('pane_count', 0)} panes",
        label,
        "current" if focused else "-",
        str(running),
    ]


def build_lines(
    agents: list[dict],
    workspaces: list[dict],
    tabs: list[dict],
    recent: list,
    home: str,
    branch_by_row: dict[int, str] | None = None,
) -> str:
    """Merge agents + workspaces into the tab-separated list (old picker.sh
    byte-equivalent: agents block first, then spaces, one row per line).

    *branch_by_row* maps a 1-based row index to a git branch name that is
    appended to that row's display as ``(branch)``.  ``None`` keeps the
    legacy output byte-identical.
    """
    wsmap = {w.get("workspace_id", ""): w for w in workspaces}
    tabmap = {t.get("tab_id", ""): tab_display_label(t.get("label", "")) for t in tabs}

    rows = []
    index = 1
    for agent in sorted_agents(agents, recent):
        row = agent_row(agent, wsmap, tabmap, home)
        if branch_by_row is not None and index in branch_by_row:
            row[F_DISPLAY] = with_branch(row[F_DISPLAY], branch_by_row[index])
        rows.append("\t".join(row))
        index += 1
    for space in sorted_workspaces(workspaces, recent):
        wid = space.get("workspace_id", "")
        running = sum(
            1
            for a in agents
            if a.get("workspace_id") == wid and _is_running(a.get("agent_status", ""))
        )
        row = space_row(space, running)
        if branch_by_row is not None and index in branch_by_row:
            row[F_DISPLAY] = with_branch(row[F_DISPLAY], branch_by_row[index])
        rows.append("\t".join(row))
        index += 1
    if not rows:
        return ""
    return "\n".join(rows) + "\n"


# ---- pure: close decision / cursor / fzf output ---------------------------


def close_plan(kind: str, raw: str, running: str, name: str) -> tuple[bool, str | None]:
    """Decide whether a ctrl+x close needs confirmation.

    Mirrors the old do_close rules: agent working/blocked, the current
    space, or a space with running agents all ask first.
    """
    if kind == "agent":
        if raw in ("working", "blocked"):
            return True, f"close agent {name}? (状态: {raw})"
        return False, None
    if raw == "current":
        return True, f"close space {name}? (当前 space)"
    try:
        n = int(running)
    except (TypeError, ValueError):
        n = 0
    if n > 0:
        return True, f"close space {name}? ({n} 个 agent 运行中)"
    return False, None


def next_cursor_index(*, closed: bool, idx: int) -> int:
    """Where to park the cursor after a refresh: above the deleted row
    (clamped to 1) when a close happened, on the same row otherwise."""
    if closed:
        return max(idx - 1, 1)
    return idx


def parse_fzf_output(out: str) -> tuple[str, str, str]:
    """fzf --print-query --expect output: query / pressed key ('' for
    enter) / selected line."""
    lines = out.splitlines()
    query = lines[0] if len(lines) > 0 else ""
    key = lines[1] if len(lines) > 1 else ""
    line = lines[2] if len(lines) > 2 else ""
    return query, key, line


# ---- pure: recency / record / toggle / preview ----------------------------


def recency_update(recent: list, workspace_id: str) -> list:
    """New recency: the focused workspace first, then the rest minus it,
    capped at MAX_RECENT."""
    return ([workspace_id] + [w for w in recent if w != workspace_id])[:MAX_RECENT]


def parse_event_workspace_id(event_json: str) -> str:
    """Extract the workspace id from a workspace.focused EventEnvelope
    (`.data.workspace_id`, top-level `.workspace_id` as fallback)."""
    try:
        payload = json.loads(event_json)
    except (json.JSONDecodeError, TypeError):
        return ""
    wid = (
        payload.get("data", {}).get("workspace_id")
        if isinstance(payload.get("data"), dict)
        else None
    )
    if not wid:
        wid = payload.get("workspace_id")
    return str(wid) if wid else ""


def normalize_state(raw: dict | None) -> dict:
    """Tolerate missing/corrupt/old-format state: degrade to defaults."""
    if not isinstance(raw, dict):
        return {"current": None, "previous": None, "recent": []}
    recent = raw.get("recent", [])
    if not isinstance(recent, list):
        recent = []
    return {
        "current": raw.get("current") or None,
        "previous": raw.get("previous") or None,
        "recent": recent,
    }


def record_state(new_ws: str, old: dict) -> dict | None:
    """New state after a workspace.focused event; None → no change (same
    workspace, like the old hook's silent exit)."""
    if new_ws == old["current"]:
        return None
    return {
        "current": new_ws,
        "previous": old["current"],
        "recent": recency_update(old["recent"], new_ws),
    }


def toggle_state(old: dict, target: str, *, ok: bool) -> dict:
    """New state after a toggle: success swaps current/previous and moves
    the target to the recency front; failure drops previous only.

    Callers must already have guarded the silent no-op (no record / no
    previous) before calling.
    """
    if ok:
        return {
            "current": target,
            "previous": old["current"],
            "recent": recency_update(old["recent"], target),
        }
    return {
        "current": old["current"],
        "previous": None,
        "recent": old["recent"],
    }


def preview_text(line: str) -> str:
    """fzf preview renderer — old preview.sh byte-equivalent detail block."""
    if not line:
        return ""
    fields = line.split("\t")
    name = fields[F_NAME] if len(fields) > F_NAME else ""
    kind = fields[F_KIND] if len(fields) > F_KIND else ""
    target = fields[F_TARGET] if len(fields) > F_TARGET else ""
    status = fields[F_STATUS] if len(fields) > F_STATUS else ""
    ws = fields[F_WS] if len(fields) > F_WS else ""
    cwd = fields[F_CWD] if len(fields) > F_CWD else ""
    title = fields[F_TITLE] if len(fields) > F_TITLE else ""

    out = [f"{COLOR_BOLD}{name}{RESET}", ""]
    if kind == "agent":
        out += [
            f"状态:   {status}",
            f"space:  {ws}",
            f"cwd:    {cwd}",
            f"终端:   {title}",
            f"pane:   {target}",
        ]
    else:
        out += [f"id:     {target}", f"panes:  {title}", f"状态:   {status}"]
    return "\n".join(out) + "\n"


# ---- shell: herdr CLI ------------------------------------------------------


class FetchError(Exception):
    """herdr data could not be fetched/parsed (→ fail() with the message)."""


_LAST_STDERR = ""


def herdr(*args: str, timeout: int = 10) -> dict | None:
    """Run a herdr CLI command and return parsed JSON; None on any failure."""
    global _LAST_STDERR
    try:
        p = subprocess.run(
            [_HERDR, *args], capture_output=True, text=True, timeout=timeout
        )
    except (OSError, subprocess.TimeoutExpired):
        _LAST_STDERR = ""
        return None
    _LAST_STDERR = p.stderr or ""
    if p.returncode != 0:
        return None
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return None


def current_branch(cwd: str, timeout: int = 2) -> str | None:
    """git -C <cwd> branch --show-current；任何失败/空输出 → None。"""
    if not cwd:
        return None
    try:
        p = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if p.returncode != 0:
        return None
    out = p.stdout.strip()
    return out or None


def collect_unique_cwds(agents: list[dict]) -> list[str]:
    """按出现顺序收集非空且去重的 agent cwd。"""
    seen = set()
    out = []
    for agent in agents:
        cwd = agent.get("cwd") or ""
        if cwd and cwd not in seen:
            seen.add(cwd)
            out.append(cwd)
    return out


def resolve_branch_by_row(
    agents: list[dict],
    workspaces: list[dict],
    branch_by_cwd: dict[str, str],
    worktree_branches: dict[str, str],
) -> dict[int, str]:
    """构建 1-based 行号 → 分支名 的映射。

    agent 行按自己的 cwd；space 行优先用 worktree 映射，否则用该 space
    下第一个 agent 的 cwd 分支（space 本身没有 cwd）。

    纯函数：分支查询已由调用方完成，这里只做行号对齐。
    """
    result = {}
    index = 1
    for agent in agents:
        cwd = agent.get("cwd") or ""
        if cwd in branch_by_cwd:
            result[index] = branch_by_cwd[cwd]
        index += 1
    for space in workspaces:
        wid = space.get("workspace_id", "")
        branch = worktree_branches.get(wid)
        if not branch:
            for agent in agents:
                if agent.get("workspace_id") == wid:
                    cwd = agent.get("cwd") or ""
                    branch = branch_by_cwd.get(cwd)
                    if branch:
                        break
        if branch:
            result[index] = branch
        index += 1
    return result


def worktree_branch_map() -> dict[str, str]:
    """herdr worktree list → {open_workspace_id: branch}；失败 → {}。"""
    data = herdr("worktree", "list")
    if data is None:
        return {}
    worktrees = data.get("result", {}).get("worktrees", [])
    return {
        t.get("open_workspace_id"): t.get("branch")
        for t in worktrees
        if t.get("open_workspace_id") and t.get("branch")
    }


def _err_tail() -> str:
    """First 5 lines of the last herdr stderr (for warn messages)."""
    return "\n".join(_LAST_STDERR.splitlines()[:5])


def _state_dir() -> Path:
    explicit = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if explicit:
        return Path(explicit)
    return Path.home() / ".config" / "herdr" / "plugins" / "state" / "herdr-switch"


def _state_file() -> Path:
    return _state_dir() / STATE_FILE_NAME


def load_state(state_dir: Path) -> dict:
    """Read prev-space.json tolerantly (missing/corrupt → defaults)."""
    try:
        raw = json.loads((state_dir / STATE_FILE_NAME).read_text())
    except (OSError, json.JSONDecodeError):
        raw = None
    return normalize_state(raw)


def save_state(state_dir: Path, state: dict) -> None:
    """Atomic write (tmp + os.replace). Format matches jq 1.7's pretty
    output (2-space indent) so the state file stays byte-compatible with
    the old record.sh / toggle.sh."""
    state_dir.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(state_dir), prefix="prev-space.json.tmp.")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(state, f, indent=2)
            f.write("\n")
        os.replace(tmp, str(state_dir / STATE_FILE_NAME))
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def fetch_data() -> tuple[list, list, list, str, str]:
    """Pull agent/workspace/tab lists and validate; raises FetchError."""
    agents_json = herdr("agent", "list")
    if agents_json is None:
        raise FetchError("herdr agent list 失败(herdr 在运行吗?)")
    ws_json = herdr("workspace", "list")
    if ws_json is None:
        raise FetchError("herdr workspace list 失败")
    tabs_json = herdr("tab", "list")
    if tabs_json is None:
        raise FetchError("herdr tab list 失败")

    def _require(payload, key, label):
        result = payload.get("result") if isinstance(payload, dict) else None
        value = result.get(key) if isinstance(result, dict) else None
        if value is None:
            raise FetchError(f"{label} 返回了无法解析的数据")
        return value

    agents = _require(agents_json, "agents", "agent list")
    workspaces = _require(ws_json, "workspaces", "workspace list")
    tabs = _require(tabs_json, "tabs", "tab list")

    cur_ws = next((w.get("label", "") for w in workspaces if w.get("focused")), "?")
    cur_tab = next(
        (tab_display_label(t.get("label", "")) for t in tabs if t.get("focused")), "?"
    )
    return agents, workspaces, tabs, cur_ws, cur_tab


def header_text(cur_ws: str, cur_tab: str) -> str:
    return (
        f"当前 space: {cur_ws} · 当前 tab: {cur_tab}"
        "    enter=focus · alt+enter=attach · ctrl+x=close · esc=退出 · 最近使用在底部"
    )


# ---- shell: fzf ------------------------------------------------------------


def _fzf_base_args() -> list[str]:
    return [
        "fzf",
        "--ansi",
        "--layout=reverse-list",
        "--sync",
        "--delimiter",
        "\t",
        "--with-nth=1",
        "--no-multi",
        "--no-sort",
        "--tiebreak=index",
    ]


def run_fzf(
    lines: str, query: str, binds: str, header: str, preview_cmd: str
) -> tuple[int, str]:
    """Interactive fzf; returns (returncode, stdout)."""
    args = _fzf_base_args() + [
        "--header",
        header,
        "--preview",
        preview_cmd,
        "--preview-window=right:40%",
        "--bind",
        binds,
        "--print-query",
        "--expect=alt-enter,ctrl-x",
        "--query",
        query,
    ]
    try:
        p = subprocess.run(
            args, input=lines, capture_output=True, text=True, timeout=300
        )
        return p.returncode, p.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def run_fzf_filter(query: str, lines: str) -> list[str]:
    """fzf --filter replica of the interactive view (ANSI-stripped rows)."""
    args = _fzf_base_args() + ["--filter", query]
    try:
        p = subprocess.run(
            args, input=lines, capture_output=True, text=True, timeout=30
        )
        return p.stdout.splitlines()
    except (OSError, subprocess.TimeoutExpired):
        return []


# ---- shell: terminal -------------------------------------------------------


def _read_key() -> str:
    """Read one keypress without echo; "" when stdin is not a tty."""
    import termios
    import tty

    try:
        fd = sys.stdin.fileno()
        if not os.isatty(fd):
            return ""
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            return sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
    except Exception:
        return ""


def fail(msg: str) -> NoReturn:
    """Fatal: popup closes when we exit, so keep it open long enough to read."""
    print(f"{COLOR_RED}{msg}{RESET}", file=sys.stderr)
    print(f"{COLOR_GRAY}按任意键关闭…{RESET}", file=sys.stderr, end="")
    _read_key()
    sys.exit(1)


def warn(msg: str) -> None:
    """Non-fatal: show an error, wait for a key, stay in the loop."""
    print(f"{COLOR_RED}{msg}{RESET}", file=sys.stderr)
    print(f"{COLOR_GRAY}按任意键继续…{RESET}", file=sys.stderr, end="")
    _read_key()
    print("\n", file=sys.stderr)


def _confirm(prompt: str) -> bool:
    print(f"{COLOR_YELLOW}{prompt} [y/N] {RESET}", end="")
    ans = _read_key()
    print()
    return ans.lower() == "y"


# ---- shell: actions ---------------------------------------------------------


def do_close(kind: str, target: str, name: str, raw: str, running: str) -> bool:
    """ctrl+x close flow. True → closed (list shrank); False → cancel/fail."""
    need, msg = close_plan(kind, raw, running, name)
    if need:
        assert msg is not None  # close_plan supplies a message when confirming
        if not _confirm(msg):
            print(f"{COLOR_GRAY}已取消{RESET}")
            return False
    if kind == "agent":
        if herdr("pane", "close", target) is None:
            warn(f"pane close 失败: {name}\n{_err_tail()}")
            return False
        print(f"{COLOR_GRAY}closed agent {name}{RESET}")
    else:
        if herdr("workspace", "close", target) is None:
            warn(f"workspace close 失败: {name}\n{_err_tail()}")
            return False
        print(f"{COLOR_GRAY}closed space {name}{RESET}")
    return True


def do_focus(kind: str, target: str, name: str) -> bool:
    """enter → focus; True → popup should close."""
    if kind == "agent":
        if herdr("agent", "focus", target) is None:
            warn(f"agent focus 失败: {name}\n{_err_tail()}")
            return False
    else:
        if herdr("workspace", "focus", target) is None:
            warn(f"workspace focus 失败: {name}\n{_err_tail()}")
            return False
    return True


def do_attach(target: str, name: str) -> bool:
    """alt+enter → agent attach --takeover; True → popup should close."""
    if herdr("agent", "attach", target, "--takeover") is None:
        warn(f"agent attach 失败: {name}\n{_err_tail()}")
        return False
    return True


# ---- subcommands ------------------------------------------------------------


def sub_picker() -> None:
    here = Path(__file__).resolve().parent
    preview_cmd = f"uv run {shlex.quote(str(here / 'switch.py'))} preview {{}}"
    recent = load_state(_state_dir())["recent"]
    query = ""
    next_index: int | None = None

    while True:
        try:
            agents, workspaces, tabs, cur_ws, cur_tab = fetch_data()
        except FetchError as e:
            fail(str(e))
        lines = build_lines(agents, workspaces, tabs, recent, str(Path.home()))

        # Inline git branch on every row: resolve once per unique cwd (agents
        # in the same repo share a cwd) plus herdr's native worktree branches
        # for spaces. Resolved at build time — no focus:reload, so fzf
        # navigation stays untouched.
        try:
            branch_by_cwd = {
                cwd: current_branch(cwd) for cwd in collect_unique_cwds(agents)
            }
            worktree_branches = worktree_branch_map()
            branch_by_row = resolve_branch_by_row(
                agents, workspaces, branch_by_cwd, worktree_branches
            )
            lines = build_lines(
                agents, workspaces, tabs, recent, str(Path.home()), branch_by_row
            )
        except Exception as e:  # [DEBUG-herdr-switch] 分支装饰失败时留痕
            import traceback

            with open("/tmp/herdr-switch-branch-err.log", "a") as f:
                f.write(f"{time.strftime('%H:%M:%S')} {type(e).__name__}: {e}\n")
                f.write(traceback.format_exc())
        else:
            with open("/tmp/herdr-switch-branch-err.log", "a") as f:
                f.write(
                    f"{time.strftime('%H:%M:%S')} OK cwds={len(branch_by_cwd)} rows={len(branch_by_row)}\n"
                )

        binds = "alt-enter:accept"
        if next_index is not None:
            binds += f",start:pos({next_index}),load:pos({next_index})"
        else:
            binds += ",start:last,load:last"

        # Always-on debug dumps (same files as the old picker.sh).
        try:
            (Path("/tmp/herdr-switch-lines.txt")).write_text(lines)
            debug = json.dumps(
                {
                    "ts": time.strftime("%H:%M:%S"),
                    "pid": os.getpid(),
                    "recent": recent,
                    "binds": binds,
                },
                separators=(",", ":"),
            )
            (Path("/tmp/herdr-switch-recent.txt")).write_text(debug + "\n")
        except OSError:
            pass

        rc, out = run_fzf(
            lines,
            query,
            binds=binds,
            header=header_text(cur_ws, cur_tab),
            preview_cmd=preview_cmd,
        )
        next_index = None
        if rc != 0:
            sys.exit(0)  # cancelled / fzf missing → silent exit

        query, key, line = parse_fzf_output(out)
        if not line:
            continue
        fields = line.split("\t")
        kind = fields[F_KIND]
        target = fields[F_TARGET]
        name = fields[F_NAME]
        raw = fields[F_RAW]
        running = fields[F_RUNNING]

        if key == "ctrl-x":
            filtered = run_fzf_filter(query, lines)
            try:
                idx = filtered.index(line) + 1
            except ValueError:
                idx = 1
            closed = do_close(kind, target, name, raw, running)
            next_index = next_cursor_index(closed=closed, idx=idx)
            continue
        if key == "alt-enter":
            if kind != "agent":
                warn(f"alt+enter 只能用于 agent(当前选中: space {name})")
                continue
            if do_attach(target, name):
                break
            continue
        # enter → focus
        if do_focus(kind, target, name):
            break


def sub_preview() -> None:
    line = sys.argv[2] if len(sys.argv) > 2 else ""
    sys.stdout.write(preview_text(line))


def sub_record() -> None:
    wid = parse_event_workspace_id(os.environ.get("HERDR_PLUGIN_EVENT_JSON", ""))
    if not wid:
        return
    state_dir = _state_dir()
    new = record_state(wid, load_state(state_dir))
    if new is None:
        return
    save_state(state_dir, new)


def sub_toggle() -> None:
    state_dir = _state_dir()
    if not (_state_file()).exists():
        return
    old = load_state(state_dir)
    target = old["previous"]
    if not target:
        return
    if herdr("workspace", "focus", target) is None:
        # Target no longer exists: forget it, keep current + recency.
        save_state(state_dir, toggle_state(old, target, ok=False))
        return
    # Toast banner: which space we just landed on (herdr TUI toast).
    label = target
    data = herdr("workspace", "get", target)
    if data is not None:
        label = data.get("result", {}).get("workspace", {}).get("label") or target
    herdr(
        "notification",
        "show",
        f"→ {label}",
        "--body",
        f"workspace {target}",
        "--sound",
        "none",
    )
    save_state(state_dir, toggle_state(old, target, ok=True))


def sub_open() -> None:
    herdr_bin = os.environ.get("HERDR_BIN_PATH", "herdr")
    plugin_id = os.environ.get("HERDR_PLUGIN_ID", "herdr-switch")
    os.execvp(
        herdr_bin,
        [
            herdr_bin,
            "plugin",
            "pane",
            "open",
            "--plugin",
            plugin_id,
            "--entrypoint",
            "picker",
        ],
    )


SUBCOMMANDS = {
    "picker": sub_picker,
    "preview": sub_preview,
    "record": sub_record,
    "toggle": sub_toggle,
    "open": sub_open,
}


# ---- entry point ---------------------------------------------------------


def main() -> None:
    sub = sys.argv[1] if len(sys.argv) > 1 else ""
    handler = SUBCOMMANDS.get(sub)
    if handler is None:
        print(f"usage: switch.py <{'|'.join(SUBCOMMANDS)}>", file=sys.stderr)
        sys.exit(2)
    try:
        handler()
    except Exception:
        # Never throw from a background hook; log to stderr for herdr's
        # plugin command log.
        import traceback

        traceback.print_exc(file=sys.stderr)


if __name__ == "__main__":
    main()
