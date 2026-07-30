"""CLI entry point: argument parsing, source-repo resolution, and dispatch."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from typing import Optional, Sequence

from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.defaults import run_clean_defaults, run_presetup_defaults
from worktree_hooks.plugin import call_plugin_hook, resolve_plugin

COMMANDS = ("presetup", "clean", "list")


# ---------------------------------------------------------------------------
# Source-repo auto-derivation
# ---------------------------------------------------------------------------

def resolve_source_repo(worktree_path: str) -> Optional[str]:
    """Derive the *source repository* root from a worktree or repo path.

    Priority:
    1. If the path is a git worktree, resolve its shared (main) repo root via
       ``git rev-parse --git-common-dir``.
    2. If the path *is* the main repository root, return it as-is.
    3. Return *None* when the path is not inside a git repository.
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=worktree_path,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None

    if result.returncode != 0:
        # Not a git repository or git not available
        return None

    git_common_dir = result.stdout.strip()
    if not git_common_dir:
        return None

    git_common_dir = os.path.abspath(
        os.path.join(worktree_path, git_common_dir),
    )

    # Walk up the resolved --git-common-dir path to find a ".git"
    # component — its parent is the source repository root.
    #
    #   /repo/.git               → walk: /.git is basename → parent = /repo
    #   /repo/.git/worktrees/sc  → walk: .git is a component → parent = /repo
    #
    parent = git_common_dir
    while True:
        if os.path.basename(parent) == ".git":
            return os.path.dirname(parent)
        new_parent = os.path.dirname(parent)
        if new_parent == parent:  # reached filesystem root
            break
        parent = new_parent

    # Fallback: treat the worktree path itself as the repo root
    # (happens when running inside the main worktree / non-worktree clone).
    if os.path.isdir(os.path.join(worktree_path, ".git")):
        return worktree_path

    return None


def _resolve_worktree_path(cwd: str, args_path: Optional[str]) -> str:
    """Determine the worktree path from CLI args or CWD."""
    if args_path:
        return os.path.abspath(args_path)
    return os.path.abspath(cwd)


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="worktree-hooks",
        description="Project-level worktree lifecycle hooks.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=False,
        help="Enable verbose output",
    )
    parser.add_argument(
        "command",
        choices=COMMANDS,
        help="Hook command to run",
    )
    parser.add_argument(
        "source_repo",
        nargs="?",
        default=None,
        help=(
            "Source repository path (auto-derived from worktree if omitted)"
        ),
    )
    parser.add_argument(
        "worktree_path",
        nargs="?",
        default=None,
        help=(
            "Worktree path (defaults to CWD when source_repo is omitted, "
            "or required when source_repo is given)"
        ),
    )
    return parser


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """Parse CLI arguments, handling positional overloads."""
    parser = build_parser()
    args = parser.parse_args(argv)

    # uv run --directory changes os.getcwd() to the package dir, so use
    # $PWD (preserved by the bash wrapper / shell) when available.
    cwd = os.environ.get("PWD") or os.getcwd()

    # Cases:
    #   1. No positional args           → auto-derive both
    #   2. One positional arg           → it's the worktree_path
    #   3. Two positional args          → source_repo + worktree_path
    if args.source_repo is None:
        # No positional args: auto-derive both
        args.worktree_path = _resolve_worktree_path(cwd, None)
        args.source_repo = resolve_source_repo(args.worktree_path)
    elif args.worktree_path is None:
        # One positional arg: it's the worktree_path, auto-derive source
        args.worktree_path = os.path.abspath(args.source_repo)
        args.source_repo = resolve_source_repo(args.worktree_path)
    else:
        # Two positional args: use both as-is
        args.source_repo = os.path.abspath(args.source_repo)
        args.worktree_path = os.path.abspath(args.worktree_path)

    if args.source_repo is None:
        parser.error(
            "Cannot determine source repository. "
            "Run from inside a git worktree/repo, or specify paths explicitly."
        )

    return args


# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

def cmd_presetup(ctx: WorktreeContext) -> None:
    """Run presetup: defaults first, then plugin."""
    if ctx.verbose:
        print("Running presetup defaults…", file=sys.stderr)
    run_presetup_defaults(ctx)

    plugin = resolve_plugin(ctx.source_repo)
    if plugin and ctx.verbose:
        print("Running plugin presetup…", file=sys.stderr)
    call_plugin_hook(plugin, "presetup", ctx)


def cmd_clean(ctx: WorktreeContext) -> None:
    """Run clean: plugin first (so it can read resources), then defaults."""
    plugin = resolve_plugin(ctx.source_repo)
    if plugin and ctx.verbose:
        print("Running plugin clean…", file=sys.stderr)
    call_plugin_hook(plugin, "clean", ctx)

    if ctx.verbose:
        print("Running clean defaults…", file=sys.stderr)
    run_clean_defaults(ctx)


def cmd_list(ctx: WorktreeContext) -> None:
    """List available hooks for the worktree."""
    print(f"source_repo:  {ctx.source_repo}", file=sys.stderr)
    print(f"worktree:     {ctx.worktree_path}", file=sys.stderr)
    print(f"worktree_name: {ctx.worktree_name}", file=sys.stderr)

    plugin = resolve_plugin(ctx.source_repo)
    if plugin is None:
        print("plugin:       (none)", file=sys.stderr)
    else:
        hooks = []
        for name in ("presetup", "clean"):
            if hasattr(plugin, name):
                hooks.append(name)
        print(f"plugin hooks: {', '.join(hooks) or '(none)'}", file=sys.stderr)


COMMAND_DISPATCH = {
    "presetup": cmd_presetup,
    "clean": cmd_clean,
    "list": cmd_list,
}


# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

def main(argv: Optional[Sequence[str]] = None) -> None:
    """Main entry point: parse, build context, dispatch, handle errors."""
    args = parse_args(argv)

    ctx = WorktreeContext(
        source_repo=args.source_repo,
        worktree_path=args.worktree_path,
        verbose=args.verbose,
    )

    dispatch = COMMAND_DISPATCH.get(args.command)
    if dispatch is None:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        sys.exit(2)

    try:
        dispatch(ctx)
    except Exception as exc:
        print(f"Error running {args.command}: {exc}", file=sys.stderr)
        if ctx.verbose:
            import traceback
            traceback.print_exc(file=sys.stderr)
        sys.exit(2)
