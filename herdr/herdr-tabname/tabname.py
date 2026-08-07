#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
herdr-tabname: Auto-name tabs after the foreground process.

Environment (set by herdr plugin hook):
    HERDR_PLUGIN_EVENT  — "startup" | "tab.focused" | "tab.created"
    HERDR_TAB_ID        — tab_id (only for tab.focused / tab.created)
    HERDR_PANE_ID       — focused pane_id of the tab (only for tab.focused / tab.created)
    HERDR_BIN_PATH      — path to herdr binary
    HERDR_PLUGIN_STATE_DIR — plugin state directory
"""

import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# ---- constants -----------------------------------------------------------

SHELL_NAMES = frozenset({"bash", "zsh", "fish", "sh", "dash", "ksh", "tcsh", "csh"})
MAX_LABEL_LENGTH = 20

# ---- helpers -------------------------------------------------------------

_HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")


def _herdr(*args: str, timeout: int = 10) -> dict | None:
    """Run a herdr CLI command and return the parsed JSON response.

    Returns None on any error (binary not found, non-zero exit, timeout,
    invalid JSON).  The caller is responsible for checking the result.
    """
    try:
        out = subprocess.run(
            [_HERDR, *args],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return None


def _state_dir() -> Path:
    """Return the same state root used by herdr's plugin runtime.

    Hooks normally receive HERDR_PLUGIN_STATE_DIR from herdr. The fallback
    mirrors herdr's release default so local runs and tests inspect the same
    state location instead of accidentally creating a config-dir copy.
    """
    explicit = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if explicit:
        return Path(explicit)

    state_root = os.environ.get("XDG_STATE_HOME")
    base = Path(state_root) if state_root else Path.home() / ".local" / "state"
    return base / "herdr" / "plugins" / "herdr-tabname"


def _state_file() -> Path:
    return _state_dir() / "tabs.json"


def _load_state() -> dict:
    """Load the plugin state file.  Missing/corrupt → empty state."""
    f = _state_file()
    if not f.exists():
        return {"tabs": {}}
    try:
        data = json.loads(f.read_text())
        if not isinstance(data, dict) or "tabs" not in data:
            return {"tabs": {}}
        return data
    except (json.JSONDecodeError, OSError):
        return {"tabs": {}}


def _save_state(state: dict) -> None:
    """Atomically write state (tmp + os.replace)."""
    _state_dir().mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(_state_dir()), prefix="tabs.json.tmp.")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(state, f, indent=2)
            f.write("\n")
        os.replace(tmp, str(_state_file()))
    except Exception:
        # Best-effort cleanup of the temp file.
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _locked_load_and_save(update_fn):
    """Load state, call *update_fn(state)*, then save state.

    Uses *flock* on the state file to serialize concurrent hook invocations
    (tab.created and tab.focused run concurrently for the same tab).
    """
    _state_dir().mkdir(parents=True, exist_ok=True)
    lock_path = _state_dir() / ".state.lock"
    # Create lock file if needed
    lock_path.touch(exist_ok=True)

    import fcntl

    fd = os.open(str(lock_path), os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        state = _load_state()
        update_fn(state)
        _save_state(state)
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def _is_numeric(label: str) -> bool:
    """Return True if the label is a pure decimal number (herdr auto-name)."""
    return label.isdigit()


def _basename(name: str) -> str:
    """Return the last path component, stripping trailing slashes."""
    return Path(name).name


def _truncate(s: str, n: int) -> str:
    """Truncate *s* to at most *n* characters."""
    return s[:n] if len(s) > n else s


# ---- naming algorithm (pure) ---------------------------------------------


def compute_label(pane_id: str) -> str | None:
    """Compute the desired tab label for *pane_id*.

    Priority:
      1. display_agent / agent (from pane get)
      2. foreground process name (from pane process-info)
         - shell → cwd basename (or shell name if cwd missing)
      3. undetectable → None (keep current name)

    Returned label is already basename'd and truncated to MAX_LABEL_LENGTH.
    """
    # 1. Agent priority
    data = _herdr("pane", "get", pane_id)
    if data is not None:
        pane = data.get("result", {}).get("pane", {})
        agent = pane.get("display_agent") or pane.get("agent")
        if agent:
            return _truncate(agent, MAX_LABEL_LENGTH)

    # 2. Foreground process
    data = _herdr("pane", "process-info", "--pane", pane_id)
    if data is None:
        return None
    procs = (
        data.get("result", {}).get("process_info", {}).get("foreground_processes", [])
    )
    if not procs:
        return None
    proc = procs[0]
    name = proc.get("name", "")
    if not name:
        return None

    # 2a. Idle shell → cwd basename
    if name in SHELL_NAMES:
        cwd = proc.get("cwd") or ""
        if cwd:
            return _truncate(_basename(cwd), MAX_LABEL_LENGTH)
        # No cwd available → fall back to the shell name itself
        return _truncate(name, MAX_LABEL_LENGTH)

    # 2b. Regular process
    return _truncate(_basename(name), MAX_LABEL_LENGTH)


# ---- rename logic --------------------------------------------------------


def _protected_rename_tab(
    tab_id: str,
    pane_id: str,
    *,
    current_label: str | None = None,
    retry: bool = False,
) -> None:
    """Conditionally rename *tab_id* to the computed label of *pane_id*.

    Protection rules (Q2=a):
      - If the current label is a pure number (herdr auto-name) → may rename.
      - If the current label matches the plugin's recorded label → ours → may rename.
      - Otherwise → user manually renamed → remove from state, never touch.

    *current_label* can be passed in to avoid a redundant tab list call when
    the caller already has it (e.g. startup sweep).

    When *retry* is True (tab.focused / tab.created hooks), a single retry
    with a short delay is attempted if the foreground process is not yet
    detectable (shell startup race).

    Concurrent hooks (tab.created + tab.focused for the same new tab) are
    serialized via *flock* on the state directory.
    """

    # Phase 1 (no lock): resolve current label
    if current_label is None:
        data = _herdr("tab", "list")
        if data is None:
            return
        current = None
        for t in data.get("result", {}).get("tabs", []):
            if t.get("tab_id") == tab_id:
                current = t.get("label")
                break
        if current is None:
            return
    else:
        current = current_label

    # Phase 2 (no lock): compute label, retry for shell startup race
    computed = compute_label(pane_id)
    if computed is None and retry:
        time.sleep(0.5)
        computed = compute_label(pane_id)
    if computed is None:
        return

    # Phase 3 (locked): protection check + rename + state update
    def _update(state):
        tabs_state = state["tabs"]
        plugin_label = tabs_state.get(tab_id, {}).get("plugin_label")
        if not (_is_numeric(current) or current == plugin_label):
            tabs_state.pop(tab_id, None)
            return  # user-named
        if computed != current:
            if _herdr("tab", "rename", tab_id, computed) is None:
                return  # rename failed
        tabs_state[tab_id] = {"plugin_label": computed}

    _locked_load_and_save(_update)


# ---- event handlers ------------------------------------------------------


def _handle_sweep() -> None:
    """Startup sweep: rename every managed tab.

    One-shot at startup.  Skips user-named tabs early (saves CLI calls).
    """
    tabs_data = _herdr("tab", "list")
    if tabs_data is None:
        return
    all_tabs = tabs_data.get("result", {}).get("tabs", [])
    if not all_tabs:
        return

    panes_data = _herdr("pane", "list")
    if panes_data is None:
        return
    all_panes = panes_data.get("result", {}).get("panes", [])

    # Build tab_id → [pane_id] map
    panes_by_tab: dict[str, list[str]] = {}
    for p in all_panes:
        tid = p.get("tab_id")
        pid = p.get("pane_id")
        if tid and pid:
            panes_by_tab.setdefault(tid, []).append(pid)

    for tab in all_tabs:
        tab_id = tab.get("tab_id")
        if not tab_id:
            continue
        label = tab.get("label", "")
        pane_count = tab.get("pane_count", 0)
        if pane_count == 0:
            continue

        pane_ids = panes_by_tab.get(tab_id, [])
        if not pane_ids:
            continue

        # Resolve the focused pane of this tab
        if pane_count == 1:
            pane_id = pane_ids[0]
        else:
            layout = _herdr("pane", "layout", "--pane", pane_ids[0])
            if layout is None:
                continue
            pane_id = layout.get("result", {}).get("layout", {}).get("focused_pane_id")
            if not pane_id:
                continue

        _protected_rename_tab(tab_id, pane_id, current_label=label)


def _handle_focus_or_created() -> None:
    """Handle tab.focused / tab.created: rename the single tab."""
    tab_id = os.environ.get("HERDR_TAB_ID", "")
    pane_id = os.environ.get("HERDR_PANE_ID", "")
    event = os.environ.get("HERDR_PLUGIN_EVENT", "")
    if not tab_id or not pane_id:
        return

    # On tab.created the PTY shell is still starting up (shell startup
    # scripts like /usr/libexec/path_helper on macOS).  Wait briefly so
    # the foreground process stabilises to the shell itself.
    if event == "tab.created":
        time.sleep(1.0)

    _protected_rename_tab(tab_id, pane_id, retry=True)


# ---- entry point ---------------------------------------------------------


def main() -> None:
    event = os.environ.get("HERDR_PLUGIN_EVENT", "")
    try:
        if event == "startup":
            _handle_sweep()
        elif event in ("tab.focused", "tab.created"):
            _handle_focus_or_created()
        # Unknown event → silently ignore (future-proofing)
    except Exception:
        # Never throw from a background hook; log/discard.
        # (We use stderr so herdr's plugin command log can capture it.)
        import traceback

        traceback.print_exc(file=sys.stderr)


if __name__ == "__main__":
    main()
