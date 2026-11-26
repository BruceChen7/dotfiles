"""CLI entry point: argument parsing, source-repo resolution, and dispatch."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from typing import Optional, Sequence

from worktree_hooks import hooks as hooks_mod
from worktree_hooks import rules as rules_mod
from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.defaults import run_clean_defaults, run_presetup_defaults

COMMANDS = ("presetup", "clean", "list")

LEGACY_PLUGIN_RELPATH = os.path.join(".pi", "worktree-hooks", "plugin.py")


def _warn_legacy_plugin(source_repo: str) -> None:
    """``plugin.py`` 不再执行：一条迁移提示，比静默失效好。"""
    if os.path.isfile(os.path.join(source_repo, LEGACY_PLUGIN_RELPATH)):
        print(
            "  [warn] .pi/worktree-hooks/plugin.py 已不再执行；"
            "改用 .pi/worktree-hooks.toml 的 [[rule]] / [[hook]]"
            "（见 worktree-hooks --help）",
            file=sys.stderr,
        )


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
    """Determine the worktree path from CLI args or CWD.

    相对路径按 **$PWD** 解析，不是按进程 cwd：`uv run --directory <pkg>` 会把进程 cwd
    换到包目录，用 `os.path.abspath` 会把 `worktree-hooks presetup .` 解释成包目录自己
    （在 dotfiles 里 → 铺错仓库）。
    """
    if args_path:
        return os.path.normpath(os.path.join(cwd, args_path))
    return os.path.abspath(cwd)


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

CONFIG_DOC = """\
声明式配置（全部可选；内置规则表见 `worktree-hooks list`）：

  ~/.config/worktree-hooks/config.toml   全局覆盖
  <repo>/.pi/worktree-hooks.toml         仓库覆盖（先命中先得）

  [[rule]]                               路径形状 → 补法
  match = "**/node_modules"              **/x = 任意深度叫 x；字面路径也支持
  kind  = "node_modules"                 link | linkdir | node_modules
  keep  = ["test", "test-logs"]          linkdir 专用：这些子项不链
  # disable = ["**/.nsh"]                裁掉内置规则

  [[hook]]                               对目录跑一条命令（argv，不经 shell）
  on      = "presetup"                   presetup | clean
  command = ["bash", "tools/x.sh", "{worktree}", "{name}"]
  cwd     = "{worktree}"                 可选；占位符 {worktree} {source} {name}

仓库有 `.pi/worktree-hooks/plugin.py` 时会打一条提示：那套插件钩子已不再执行。
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="worktree-hooks",
        description="Worktree presetup driven by a declarative rule table.",
        epilog=CONFIG_DOC,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=False,
        help="Enable verbose output",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        default=False,
        help="Print what presetup/clean would do, touch nothing",
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
        args.worktree_path = _resolve_worktree_path(cwd, args.source_repo)
        args.source_repo = resolve_source_repo(args.worktree_path)
    else:
        # Two positional args: use both as-is（相对路径仍按 $PWD 解析）
        args.source_repo = _resolve_worktree_path(cwd, args.source_repo)
        args.worktree_path = _resolve_worktree_path(cwd, args.worktree_path)

    if args.source_repo is None:
        parser.error(
            "Cannot determine source repository. "
            "Run from inside a git worktree/repo, or specify paths explicitly."
        )

    return args


# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

def cmd_presetup(ctx: WorktreeContext, *, dry_run: bool = False) -> None:
    """Run presetup: 规则表铺产物 → 镜像 .pi → 仓库声明的命令钩子。

    ``dry_run`` 只打印会做什么：不碰磁盘、不跑 npm、不跑钩子。
    """
    _warn_legacy_plugin(ctx.source_repo)
    if ctx.verbose:
        print("Running presetup defaults…", file=sys.stderr)
    run_presetup_defaults(ctx, dry_run=dry_run)

    hooks_mod.run_hooks(ctx, "presetup", dry_run=dry_run)


def cmd_clean(ctx: WorktreeContext, *, dry_run: bool = False) -> None:
    """Run clean: 钩子先跑（它可以先读自己的产物），再回收默认产物。"""
    _warn_legacy_plugin(ctx.source_repo)
    hooks_mod.run_hooks(ctx, "clean", dry_run=dry_run)
    if dry_run:
        run_clean_defaults(ctx, dry_run=True)
        return

    if ctx.verbose:
        print("Running clean defaults…", file=sys.stderr)
    run_clean_defaults(ctx)


def cmd_list(ctx: WorktreeContext, *, dry_run: bool = False) -> None:
    """List the effective rule table and command hooks for this repo."""
    print(f"source_repo:  {ctx.source_repo}", file=sys.stderr)
    print(f"worktree:     {ctx.worktree_path}", file=sys.stderr)
    print(f"worktree_name: {ctx.worktree_name}", file=sys.stderr)
    print(f"config:       {rules_mod.global_config_path()}", file=sys.stderr)

    rules = rules_mod.load_rules(ctx.source_repo)
    print("rules:", file=sys.stderr)
    for rule in rules:
        keep = f" keep={','.join(rule.keep)}" if rule.keep else ""
        print(f"  {rule.match:24} {rule.kind}{keep}", file=sys.stderr)

    print("hooks:", file=sys.stderr)
    hooks = hooks_mod.load_hooks(ctx.source_repo)
    if not hooks:
        print("  (none)", file=sys.stderr)
    for hook in hooks:
        print(
            f"  on {hook.on:10} {' '.join(hook.command)}  (cwd={hook.cwd})",
            file=sys.stderr,
        )

    actions = rules_mod.plan(
        rules_mod.inspect(
            ctx.source_repo,
            ctx.worktree_path,
            rules_mod.discover(ctx.source_repo, rules),
        )
    )
    print(f"candidates:   {len(actions)}", file=sys.stderr)
    for action in actions:
        print(f"  {action.action:10} {action.path}", file=sys.stderr)


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
        dispatch(ctx, dry_run=args.dry_run)
    except Exception as exc:
        print(f"Error running {args.command}: {exc}", file=sys.stderr)
        if ctx.verbose:
            import traceback
            traceback.print_exc(file=sys.stderr)
        sys.exit(2)
