#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
herdr-worktree-hooks — worktree lifecycle event hook.

Maps herdr worktree events onto the worktree-hooks CLI:
    worktree.created / worktree.opened → presetup <checkout>
    worktree.removed                  → clean <repo_root> <checkout>

Environment (set by herdr plugin hook):
    HERDR_PLUGIN_EVENT        — "worktree.created" | "worktree.opened" | "worktree.removed"
    HERDR_PLUGIN_EVENT_JSON   — full EventEnvelope; data.worktree.path is the checkout
    HERDR_PLUGIN_CONTEXT_JSON — PluginInvocationContext; .worktree.repo_root fallback

Semantics:
    - worktree.created/opened fire AFTER `git worktree add` → checkout dir exists,
      so presetup is called with one positional arg and the CLI auto-derives the
      source repo via `git rev-parse`.
    - worktree.removed fires AFTER `git worktree remove` → checkout dir is gone and
      cannot be used to derive the source repo, so repo_root is extracted from the
      event JSON and passed explicitly (two positional args).
    - No-op conditions (missing path/repo_root, unknown event) exit 0 with a
      warning; real CLI failures propagate their exit code (visible via
      `herdr plugin log`).

Override HERDR_WT_HOOKS_BIN to point at a different worktree-hooks binary
(used by test_hook.py to inject a recording shim).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

WT_HOOKS = os.environ.get("HERDR_WT_HOOKS_BIN") or os.path.expanduser(
    "~/.local/bin/worktree-hooks"
)

EVENTS_WITH_PRESETUP = ("worktree.created", "worktree.opened")


def _load_json(value: str) -> dict:
    """Parse an env-provided JSON string; malformed input degrades to {}."""
    if not value:
        return {}
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _log(message: str) -> None:
    print(f"[worktree-hooks] {message}", file=sys.stderr)


def build_command(event: str, event_json: str, context_json: str) -> list[str] | None:
    """Map an event to worktree-hooks argv, or None for a no-op (caller logs why).

    Pure function (value in / value out): testable without a live herdr.
    """
    data = _load_json(event_json).get("data") or {}
    if not isinstance(data, dict):
        return None

    worktree = data.get("worktree") or {}
    worktree_path = worktree.get("path") or ""
    if not worktree_path:
        _log(f"{event}: no worktree path in event JSON, skip")
        return None

    if event in EVENTS_WITH_PRESETUP:
        return ["presetup", worktree_path]

    if event == "worktree.removed":
        # Source repo: event's workspace snapshot first, plugin context as
        # fallback. The removed checkout dir no longer exists, so the CLI
        # cannot derive it via git.
        workspace = data.get("workspace") or {}
        repo_root = (workspace.get("worktree") or {}).get("repo_root") or ""
        if not repo_root:
            context = _load_json(context_json)
            repo_root = (context.get("worktree") or {}).get("repo_root") or ""
        if not repo_root:
            _log(
                "removed: cannot resolve source repo (workspace snapshot missing), "
                "skip clean"
            )
            return None
        return ["clean", repo_root, worktree_path]

    _log(f"unhandled event: {event}")
    return None


def main() -> int:
    event = os.environ.get("HERDR_PLUGIN_EVENT", "")
    if not event:
        _log("missing HERDR_PLUGIN_EVENT")
        return 1

    args = build_command(
        event,
        os.environ.get("HERDR_PLUGIN_EVENT_JSON", ""),
        os.environ.get("HERDR_PLUGIN_CONTEXT_JSON", ""),
    )
    if args is None:
        return 0

    _log(f"{event} → {' '.join(args)}")
    result = subprocess.run([WT_HOOKS, *args])
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
