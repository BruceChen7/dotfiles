"""声明式命令钩子：仓库只在「真的需要跑一条命令」时才留几行 toml。

为什么还需要这一层：规则表能表达**路径形状**（``**/node_modules`` 怎么补），但有些步骤
不是「补一个路径」，而是「对刚建好的目录做一次判断」—— 本项目就是
``tools/worktree-branch.sh``（新目录落在共享分支上时给它分一条自己的分支）。那类步骤
以前写在 ``.pi/worktree-hooks/plugin.py`` 里，106 行 Python 里只有一行是实质内容，
其余是 node 探测、兜底、打印。现在它是一条 4 行声明：

    [[hook]]
    on = "presetup"
    command = ["bash", "tools/worktree-branch.sh", "{worktree}", "{name}"]

占位符：``{worktree}`` / ``{source}`` / ``{name}``。``cwd`` 默认 ``{worktree}``，
同样支持占位符。

纪律：
- 钩子失败只 warn，绝不让 herdr 建 workspace 失败（与旧的 ``plugin.py`` 同口径）；
- ``--dry-run`` 只打印将执行的 argv，不跑；
- ``command`` 是 argv 数组，不经过 shell（没有引号/注入的猜谜）。
"""

from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from typing import Dict, List, Tuple

from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.rules import _read_toml

REPO_CONFIG_RELPATH = os.path.join(".pi", "worktree-hooks.toml")
GLOBAL_CONFIG_ENV = "WORKTREE_HOOKS_CONFIG"
EVENTS: Tuple[str, ...] = ("presetup", "clean")


def _fill(text: str, ctx: WorktreeContext) -> str:
    return (
        text.replace("{worktree}", ctx.worktree_path)
        .replace("{source}", ctx.source_repo)
        .replace("{name}", ctx.worktree_name)
    )


@dataclass(frozen=True)
class Hook:
    on: str
    command: Tuple[str, ...]
    cwd: str = "{worktree}"

    def __post_init__(self) -> None:
        if self.on not in EVENTS:
            raise ValueError(f"未知钩子事件：{self.on}（可选 {', '.join(EVENTS)}）")
        if not self.command:
            raise ValueError("hook.command 不能为空")


def parse_hooks(data: Dict[str, object], *, origin: str = "") -> List[Hook]:
    """toml 的 ``[[hook]]`` → Hook 列表；坏条目 warn 后跳过。"""
    hooks: List[Hook] = []
    raw_hooks = data.get("hook") or []
    if not isinstance(raw_hooks, list):
        return hooks
    for raw in raw_hooks:
        if not isinstance(raw, dict):
            continue
        on = raw.get("on")
        command = raw.get("command")
        cwd = raw.get("cwd") or "{worktree}"
        if not isinstance(on, str) or not isinstance(command, list) or not command:
            print(f"  [warn] {origin}: 钩子缺 on/command，跳过", file=sys.stderr)
            continue
        try:
            hooks.append(
                Hook(
                    on=on,
                    command=tuple(str(part) for part in command),
                    cwd=str(cwd),
                )
            )
        except ValueError as exc:
            print(f"  [warn] {origin}: {exc}，跳过", file=sys.stderr)
    return hooks


def render_argv(hook: Hook, ctx: WorktreeContext) -> List[str]:
    """占位符替换（纯函数：值进值出，命令跑不跑是壳的事）。"""
    return [_fill(part, ctx) for part in hook.command]


def render_cwd(hook: Hook, ctx: WorktreeContext) -> str:
    return _fill(hook.cwd, ctx)


def load_hooks(source_repo: str) -> List[Hook]:
    """全局配置里的钩子在前，仓库级的在后（仓库可以按事件覆盖或追加）。"""
    override = os.environ.get(GLOBAL_CONFIG_ENV)
    if override:
        global_path = os.path.abspath(override)
    else:
        base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
            os.path.expanduser("~"), ".config",
        )
        global_path = os.path.join(base, "worktree-hooks", "config.toml")
    repo_path = os.path.join(source_repo, REPO_CONFIG_RELPATH)
    return [
        *parse_hooks(_read_toml(global_path), origin=global_path),
        *parse_hooks(_read_toml(repo_path), origin=repo_path),
    ]


def run_hooks(
    ctx: WorktreeContext,
    event: str,
    *,
    dry_run: bool = False,
    timeout: int = 300,
) -> int:
    """跑 ``on == event`` 的钩子，返回失败条数（调用方只 warn，不中断）。"""
    failures = 0
    for hook in load_hooks(ctx.source_repo):
        if hook.on != event:
            continue
        argv = render_argv(hook, ctx)
        cwd = render_cwd(hook, ctx)
        if dry_run:
            print(f"would run  {' '.join(argv)}（cwd={cwd}）")
            continue
        if not os.path.isdir(cwd):
            print(f"  [warn] 钩子工作目录不存在：{cwd}", file=sys.stderr)
            failures += 1
            continue
        try:
            proc = subprocess.run(
                argv, cwd=cwd, capture_output=True, text=True,
                check=False, timeout=timeout,
            )
        except (OSError, subprocess.SubprocessError) as exc:
            print(f"  [warn] {' '.join(argv)} 跑不起来：{exc}", file=sys.stderr)
            failures += 1
            continue
        for line in (proc.stdout or "").splitlines():
            print(f"  {line}", file=sys.stderr)
        for line in (proc.stderr or "").splitlines():
            print(f"  [warn] {line}", file=sys.stderr)
        if proc.returncode != 0:
            print(
                f"  [warn] {' '.join(argv)} 退出 {proc.returncode}",
                file=sys.stderr,
            )
            failures += 1
    return failures


def hooks_for(source_repo: str, event: str) -> List[Hook]:
    return [hook for hook in load_hooks(source_repo) if hook.on == event]


__all__ = [
    "EVENTS",
    "Hook",
    "hooks_for",
    "load_hooks",
    "parse_hooks",
    "render_argv",
    "render_cwd",
    "run_hooks",
]
