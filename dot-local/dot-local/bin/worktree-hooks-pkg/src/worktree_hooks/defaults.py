"""Built-in default behaviors for worktree hooks.

Presetup: symlink artifacts from source repo into the new worktree.
Clean:    remove symlinks that presetup created.
"""

from __future__ import annotations

import os
import sys
from typing import List

from worktree_hooks.ctx import WorktreeContext

# Default list of artifacts to symlink (source → worktree).
# Can be extended later via config if needed.
DEFAULT_ARTIFACTS: List[str] = [
    ".pi",
    "node_modules",
    ".gitignore",
]

# `.pi` 下面由 skill-toggle 维护的「仓库级忽略物」。
#
# 为什么需要单独一组：worktree 只带 tracked 文件，而 `.pi/skills` 是**混合目录** ——
# tracked 的 skill 是真目录（跟着分支走），pi-kit 的 skill 是 skill-toggle 铺的
# symlink（只活在这一台机器、不进版本库）。`.pi` 已存在时整路径规则只能 skip，
# 于是 worktree 里的会话看不到那几十个 skill；而整目录 symlink 又会让 tracked skill
# 读到主 checkout 的分支内容。所以对这两个目录改成**逐条目合并**：
# 源里是 symlink 的条目镜像过去（目标原样复制），真目录/真文件留给分支。
MERGED_PI_DIRS: List[str] = [
    os.path.join(".pi", "skills"),
    os.path.join(".pi", "disabled-skills"),
]

# 合并时只镜像 symlink 条目的目录：真目录是 tracked 的 skill，不能复制。
_SYMLINK_ONLY_DIRS = {os.path.join(".pi", "skills")}

LINK = "link"
SKIP_EXISTS = "skip-exists"
SKIP_TRACKED = "skip-tracked"


def mirrored_entry_action(
    source_entry: str,
    dest_entry: str,
    *,
    symlink_only: bool,
) -> str:
    """源条目该怎么进 worktree（纯查表，不碰文件系统以外的东西）。

    - ``SKIP_EXISTS``：worktree 里已经有同名条目（含坏链）—— 幂等，也绝不覆盖 tracked。
    - ``SKIP_TRACKED``：``symlink_only`` 目录里的真目录/真文件跟着分支走，不镜像。
    - ``LINK``：建同名 symlink，目标由 :func:`mirrored_entry_target` 决定。
    """
    if os.path.lexists(dest_entry):
        return SKIP_EXISTS
    if symlink_only and not os.path.islink(source_entry):
        return SKIP_TRACKED
    return LINK


def mirrored_entry_target(source_entry: str) -> str:
    """镜像出来的链接该指向哪：源是链接就复制它的目标，否则直接指源本身。"""
    if os.path.islink(source_entry):
        return os.readlink(source_entry)
    return source_entry


def run_merge_pi_dir(ctx: WorktreeContext, relative_dir: str) -> None:
    """把一个 ``.pi`` 子目录里的仓库级条目逐个镜像进 worktree（幂等）。

    只在「源是真目录、worktree 那边也是真目录」时工作：任一端是整目录 symlink 时，
    整路径规则已经把内容带过来了，再合并只会重复。
    """
    src_dir = os.path.abspath(os.path.join(ctx.source_repo, relative_dir))
    dst_dir = os.path.join(ctx.worktree_path, relative_dir)
    dst_pi = os.path.join(ctx.worktree_path, ".pi")

    if os.path.islink(src_dir) or not os.path.isdir(src_dir):
        return
    # worktree 的 `.pi` 是整目录 symlink（源里没有 tracked `.pi`）：内容已经在，
    # 合并会重复。真目录时才往里面补条目 —— 缺的 subdir（如 disabled-skills）自己建。
    if os.path.islink(dst_pi) or not os.path.isdir(dst_pi):
        return

    symlink_only = relative_dir in _SYMLINK_ONLY_DIRS

    try:
        names = sorted(os.listdir(src_dir))
    except OSError as exc:
        print(f"  [warn] cannot read {relative_dir}: {exc}", file=sys.stderr)
        return

    pending = [
        name
        for name in names
        if mirrored_entry_action(
            os.path.join(src_dir, name),
            os.path.join(dst_dir, name),
            symlink_only=symlink_only,
        )
        == LINK
    ]
    if not pending:
        # 没有要镜像的条目就不要凭空建目录（源 `.pi/disabled-skills` 常常是空目录）。
        if ctx.verbose:
            print(f"  [skip] {relative_dir} nothing to mirror", file=sys.stderr)
        return

    try:
        os.makedirs(dst_dir, exist_ok=True)
    except OSError as exc:
        print(f"  [warn] cannot create {relative_dir}: {exc}", file=sys.stderr)
        return

    for name in names:
        src = os.path.join(src_dir, name)
        dst = os.path.join(dst_dir, name)
        action = mirrored_entry_action(src, dst, symlink_only=symlink_only)

        if action == SKIP_EXISTS:
            if ctx.verbose:
                print(f"  [skip] {relative_dir}/{name} already exists", file=sys.stderr)
            continue
        if action == SKIP_TRACKED:
            if ctx.verbose:
                print(f"  [skip] {relative_dir}/{name} is tracked (not a symlink)", file=sys.stderr)
            continue

        try:
            os.symlink(mirrored_entry_target(src), dst)
        except OSError as exc:
            print(f"  [warn] cannot mirror {relative_dir}/{name}: {exc}", file=sys.stderr)
            continue
        print(f"  [ok] mirrored {relative_dir}/{name}", file=sys.stderr)


def run_presetup_defaults(ctx: WorktreeContext) -> None:
    """Symlink default artifacts from *source_repo* into *worktree_path*.

    Strategy:
    - Use absolute-path symlinks (worktree may be at a different directory level).
    - Skip if destination already exists (file, dir, or symlink).
    - Skip if source artifact does not exist.
    - When ``.pi`` already exists in the worktree (tracked config), merge the
      repo-level skill farm from ``MERGED_PI_DIRS`` instead of skipping outright.
    """
    for artifact in DEFAULT_ARTIFACTS:
        src = os.path.abspath(os.path.join(ctx.source_repo, artifact))
        dst = os.path.join(ctx.worktree_path, artifact)

        if os.path.exists(dst) or os.path.islink(dst):
            if ctx.verbose:
                print(f"  [skip] {artifact} already exists", file=sys.stderr)
            continue

        if not os.path.exists(src):
            if ctx.verbose:
                print(
                    f"  [skip] {artifact} not in source", file=sys.stderr,
                )
            continue

        os.symlink(src, dst, target_is_directory=os.path.isdir(src))
        print(f"  [ok] symlinked {artifact} → {src}", file=sys.stderr)

    for relative_dir in MERGED_PI_DIRS:
        run_merge_pi_dir(ctx, relative_dir)


def run_clean_defaults(ctx: WorktreeContext) -> None:
    """Remove symlinks that ``run_presetup_defaults`` created.

    Strategy:
    - Only remove symlinks (``os.path.islink``), never regular files or
      directories — safe against accidental deletion.
    - Silently skip non-symlink paths.
    - For merged ``.pi`` dirs, only remove links that still point where the
      mirrored copy pointed; tracked entries and foreign links stay.
    """
    for artifact in DEFAULT_ARTIFACTS:
        path = os.path.join(ctx.worktree_path, artifact)

        if not os.path.islink(path):
            if ctx.verbose:
                print(
                    f"  [skip] {artifact} not a symlink", file=sys.stderr,
                )
            continue

        os.unlink(path)
        print(f"  [ok] removed symlink {artifact}", file=sys.stderr)

    for relative_dir in MERGED_PI_DIRS:
        _clean_merged_pi_dir(relative_dir, ctx)


def _clean_merged_pi_dir(relative_dir: str, ctx: WorktreeContext) -> None:
    src_dir = os.path.abspath(os.path.join(ctx.source_repo, relative_dir))
    dst_dir = os.path.join(ctx.worktree_path, relative_dir)

    if os.path.islink(dst_dir) or not os.path.isdir(dst_dir):
        return

    try:
        names = sorted(os.listdir(dst_dir))
    except OSError:
        return

    for name in names:
        dst = os.path.join(dst_dir, name)
        src = os.path.join(src_dir, name)

        if not os.path.islink(dst):
            continue
        # 源里已经没了的条目保持原样：删链接是 skill-toggle cleanup 的事，
        # 不是 worktree clean 的事。
        if not os.path.lexists(src):
            continue
        if os.readlink(dst) != mirrored_entry_target(src):
            continue

        os.unlink(dst)
        print(f"  [ok] removed mirrored {relative_dir}/{name}", file=sys.stderr)
