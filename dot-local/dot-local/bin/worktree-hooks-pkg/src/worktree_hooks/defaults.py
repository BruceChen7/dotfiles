"""Built-in default behaviors for worktree hooks.

Presetup: symlink whole-path artifacts from the source repo into the new
          worktree, then mirror ``.pi``'s untracked entries (git's own view)
          one by one.
Clean:    remove symlinks that presetup created.
"""

from __future__ import annotations

import os
import subprocess
import sys
from typing import List

from worktree_hooks.ctx import WorktreeContext

# Default list of artifacts to symlink whole-path (source → worktree).
# Can be extended later via config if needed.
#
# 为什么 ``.pi`` 不在这里：它是混合目录 —— tracked 部分跟着分支走，未跟踪部分
# （``plans/`` ``lessons.md`` ``extensions/`` …）只有主 checkout 有。整路径 symlink
# 在「目标已存在」时只能整条 skip（内容丢失），在「目标不存在」时又会把 tracked
# 内容也串到主 checkout 的分支上。所以 ``.pi`` 改走 :func:`mirror_pi_untracked`
# 的逐条目规则，判断源是 git 的未跟踪视图。
DEFAULT_ARTIFACTS: List[str] = [
    "node_modules",
    ".gitignore",
]

PI_DIR = ".pi"

# classify_entry 的返回值。trunk 指 git 把整棵 ``.pi`` 折叠成的一条候选
# （``.pi/`` 自身）：只保证目录存在，绝不建整目录 symlink。
LINK = "link"
SKIP = "skip"
TRUNK_NOOP = "trunk-noop"
TRUNK_MKDIR = "trunk-mkdir"


def untracked_entries(source_repo: str, rel: str = PI_DIR) -> List[str]:
    """git 眼里的「未跟踪条目」清单，相对 *rel*（默认 ``.pi``）。

    为什么用 git 而不是自己递归扫：``--directory`` 会把整棵未跟踪子树折叠成一条
    （dotfiles 只给 ``.pi/``），而 tracked + untracked 混合的目录则逐条列出未跟踪项
    （pi-mono 实测 ``.pi/extensions`` 出 37 条）。前者只需保证目录存在，后者恰好就是
    「该镜像哪些条目」的答案，省掉手写走目录 + 自己对 ignore 求值。

    - 不加 ``--exclude-standard``：被 ignore 的条目同样是「只活在这台机器上的本地
      状态」，也必须可见；``-i`` 同理不需要。
    - ``.pi/`` 自身返回 ``""``（trunk，见 :func:`classify_entry`）。
    - git 缺失 / 非 repo / 超时 / 非零退出 → 返回 ``[]``，调用方退回退化路径。
    """
    rel = rel.rstrip("/")
    try:
        proc = subprocess.run(
            ["git", "-C", source_repo, "ls-files", "-o", "--directory", "-z",
             "--", rel],
            capture_output=True,
            check=False,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if proc.returncode != 0:
        return []

    prefix = rel + "/"
    entries: List[str] = []
    for raw in proc.stdout.decode("utf-8", errors="surrogateescape").split("\0"):
        if not raw:
            continue
        # trunk 条目（`.pi` 或 `.pi/`）代表整棵子树未跟踪，只保证目录存在。
        if raw.rstrip("/") == rel:
            entries.append("")
            continue
        if raw.startswith(prefix):
            # `--directory` 给目录带尾斜杠（`.pi/plans/`），去掉后才是 symlink 名。
            entries.append(raw[len(prefix):].rstrip("/"))
    return entries


def classify_entry(
    entry: str,
    *,
    wt_pi_exists: bool,
    dst_lexists: bool,
) -> str:
    """候选条目该怎么处理（纯查表：值进值出，不碰文件系统）。

    探测（wt/.pi 是否存在、目标条目是否已存在）留给 shell 层，便于无文件系统测试。

    - trunk（``""`` / ``"."``）：worktree 的 ``.pi`` 只保证是**真目录**，绝不建整目录
      symlink —— 整目录 symlink 会让 worktree 里以 ``.pi/`` 为根的写操作落到主
      checkout（plan 会写错仓库），未来任何 tracked ``.pi`` 文件也会静默串分支。
    - 其余：目标已存在（含坏链）→ ``SKIP``，幂等且绝不覆盖 tracked / 分支自带内容。
    """
    if entry in ("", "."):
        return TRUNK_NOOP if wt_pi_exists else TRUNK_MKDIR
    if dst_lexists:
        return SKIP
    return LINK


def entry_link_target(source_pi: str, entry: str) -> str:
    """链接指向源条目**自身**（不再复制源条目的 readlink 目标）。

    少一层语义：源条目被重新指向（skill-toggle 换版本）时 worktree 自动跟随，
    clean 的归属校验也退化成一次字符串比较。
    """
    return os.path.abspath(os.path.join(source_pi, entry))


def mirror_pi_untracked(ctx: WorktreeContext) -> None:
    """把源 ``.pi`` 里 git 未跟踪的条目逐条镜像进 worktree（幂等）。

    - 有候选：worktree 的 ``.pi`` 只作为**真目录**存在（``os.makedirs``），
      其余逐条 symlink。
    - trunk 候选（整棵 ``.pi`` 未跟踪，git 折叠成一条）：绝不建整目录 symlink，
      确保目录后把源 ``.pi`` 顶层条目逐个同名链接 —— 这是 plan 实测表里 dotfiles
      样本的结果（".pi 目录 + 顶层同名 symlink"）；只浅一层 listdir，不是递归扫，
      也不涉及 ignore 求值（整棵子树未跟踪已由 git 判定）。
    - 无候选（非 git / ``.pi`` 全 tracked / ``.pi`` 空）：worktree 缺 ``.pi``
      且源存在时退回整目录 symlink（非 git 场景行为不变）。
    """
    source_pi = os.path.abspath(os.path.join(ctx.source_repo, PI_DIR))
    worktree_pi = os.path.join(ctx.worktree_path, PI_DIR)
    entries = untracked_entries(ctx.source_repo)

    if not entries:
        if not os.path.lexists(worktree_pi) and os.path.exists(source_pi):
            os.symlink(source_pi, worktree_pi, target_is_directory=True)
            print(f"  [ok] symlinked {PI_DIR} → {source_pi}", file=sys.stderr)
        return

    if any(entry in ("", ".") for entry in entries):
        # trunk：源 ``.pi`` 顶层条目逐个同名补进候选（git 折叠后不再给子条目）。
        try:
            top_level = sorted(os.listdir(source_pi))
        except OSError as exc:
            print(f"  [warn] cannot read {PI_DIR}: {exc}", file=sys.stderr)
            return
        known = set(entries)
        entries.extend(name for name in top_level if name not in known)

    for entry in entries:
        dst = os.path.join(worktree_pi, entry)
        action = classify_entry(
            entry,
            wt_pi_exists=os.path.lexists(worktree_pi),
            dst_lexists=os.path.lexists(dst),
        )

        if action == TRUNK_NOOP:
            continue
        if action == TRUNK_MKDIR:
            try:
                os.makedirs(worktree_pi, exist_ok=True)
            except OSError as exc:
                print(
                    f"  [warn] cannot create {PI_DIR}，aborting remaining "
                    f".pi entries: {exc}",
                    file=sys.stderr,
                )
                return
            continue
        if action == SKIP:
            if ctx.verbose:
                print(
                    f"  [skip] {PI_DIR}/{entry} already exists", file=sys.stderr,
                )
            continue

        # LINK：entry 可能带子路径（如 skills/how），父目录得先存在；
        # 顺便把 worktree/.pi 建出来（真目录，不是整目录 symlink）。
        parent = os.path.dirname(dst)
        try:
            os.makedirs(parent, exist_ok=True)
        except OSError as exc:
            print(
                f"  [warn] cannot create {parent}，aborting remaining "
                f".pi entries: {exc}",
                file=sys.stderr,
            )
            return
        try:
            os.symlink(entry_link_target(source_pi, entry), dst)
        except OSError as exc:
            print(
                f"  [warn] cannot mirror {PI_DIR}/{entry}: {exc}", file=sys.stderr,
            )
            continue
        print(f"  [ok] mirrored {PI_DIR}/{entry}", file=sys.stderr)


def _is_our_mirror(dst: str, source_pi: str, name: str) -> bool:
    """判断 *dst* 是不是 presetup 为源条目 *name* 建出的镜像链接。

    为什么这道校验是删除的唯一授权：clean 只回收工具自己建的链接。判据是
    readlink 指向「presetup 当年会写入的目标」—— 字面相等，或去掉路径别名后相等
    （见下）。源条目是否还在都不影响归属：源被删后的悬空链也必须回收，否则
    worktree 里永远留着死链。readlink 可能在并发 ``git worktree remove`` 时失败，
    与全模块一致：warn 后按「不是我们的」处理，绝不抛。
    """
    if not os.path.islink(dst):
        return False
    expected = entry_link_target(source_pi, name)
    try:
        actual = os.readlink(dst)
    except OSError as exc:
        print(f"  [warn] cannot readlink {PI_DIR}/{name}: {exc}", file=sys.stderr)
        return False
    if actual == expected:
        return True
    # 同一路径的符号链接等价形态：macOS 的 /tmp vs /private/tmp、源仓库搬迁后
    # 绝对路径前缀变化，字符串比较不等但 realpath 相等 —— 仍是我们建的链；
    # realpath 对不存在的叶路径也能解析前缀，故悬空链同样适用。
    #
    # 相对目标必须按**链接所在目录**解析：os.path.realpath 对相对路径是按进程 CWD
    # 解析的，直接喂进去会把外来相对链接（如 tracked 的 ``skills/shadcn ->
    # ../../.agents/skills/shadcn``）解析到毫不相干的位置，可能撞上 expected 而误删。
    actual_abs = actual if os.path.isabs(actual) else os.path.join(
        os.path.dirname(dst), actual,
    )
    return os.path.realpath(actual_abs) == os.path.realpath(expected)


def unmirror_pi_untracked(ctx: WorktreeContext) -> None:
    """回收 presetup 逐条建出来的 ``.pi`` 链接（幂等，只删我们建的）。

    两道扫，缺一不可：

    1. **候选集回收**：遍历 :func:`untracked_entries` 的当前候选，逐个回收。这是唯一
       能到达**嵌套**链接（如 ``extensions/answer.ts`` —— pi-mono 样本）的路径：
       递归扫描虽然也能看到它们，但「源条目仍在、链接仍有效」的常规情形按候选集
       直查更省事，不必等遍历完整棵目录树。
    2. **递归孤儿兜底**：候选集是**当前** git 视图，源里被删/重新 ignore 的条目已
       不在其中，但 presetup 当年建的链接还挂在原地（含
       ``<混合目录>/<entry>`` 这类嵌套孤儿）。故从 ``worktree/.pi`` 起递归遍历
       **真目录**（symlink 一律不跟随、也不下钻），用同一套归属校验收干净。

    两道都用 :func:`_is_our_mirror`（symlink + 源同名条目 lexists + 指向源条目），
    tracked 内容、外来链接一律不动；第一道删过的路径在第二道里已不是 symlink，
    自然跳过，不会重复删除或抛 FileNotFoundError。回收后留下的空目录一律不做
    rmdir：无法区分目录是 presetup 建的还是用户自己建的，空目录也不阻塞
    ``git worktree remove`` —— 也就是说 clean 不删 ``worktree/.pi`` 目录本身，
    即使它空了。
    """
    source_pi = os.path.abspath(os.path.join(ctx.source_repo, PI_DIR))
    worktree_pi = os.path.join(ctx.worktree_path, PI_DIR)

    if os.path.islink(worktree_pi) or not os.path.isdir(worktree_pi):
        # 整目录 symlink 由 run_clean_defaults 顶层的显式分支回收；缺目录则无事可做。
        return

    # 第一道：按当前候选集回收（覆盖嵌套条目）。trunk 只保证目录存在，无链接可收。
    for entry in untracked_entries(ctx.source_repo):
        if entry in ("", "."):
            continue
        dst = os.path.join(worktree_pi, entry)
        if not _is_our_mirror(dst, source_pi, entry):
            continue
        try:
            os.unlink(dst)
        except OSError as exc:
            print(
                f"  [warn] cannot remove {PI_DIR}/{entry}: {exc}",
                file=sys.stderr,
            )
            continue
        print(f"  [ok] removed mirrored {PI_DIR}/{entry}", file=sys.stderr)

    # 第二道：递归孤儿兜底（源里已删/重新 ignore、不在候选集里的链接，含嵌套）。
    for root, dirnames, filenames in os.walk(worktree_pi, followlinks=False):
        # 指向目录的 symlink 会出现在 dirnames 里：先对条目名单做快照（否则它们
        # 自己会漏掉回收），再把 symlink 从 dirnames 剔除，明确不下钻进源仓库。
        names = dirnames + filenames
        dirnames[:] = [
            name for name in dirnames
            if not os.path.islink(os.path.join(root, name))
        ]
        for name in names:
            dst = os.path.join(root, name)
            if not os.path.islink(dst):
                continue
            rel = os.path.relpath(dst, worktree_pi)
            if not _is_our_mirror(dst, source_pi, rel):
                continue
            try:
                os.unlink(dst)
            except OSError as exc:
                print(
                    f"  [warn] cannot remove {PI_DIR}/{rel}: {exc}",
                    file=sys.stderr,
                )
                continue
            print(f"  [ok] removed mirrored {PI_DIR}/{rel}", file=sys.stderr)


def run_presetup_defaults(ctx: WorktreeContext) -> None:
    """Symlink default artifacts from *source_repo* into *worktree_path*.

    Strategy:
    - Whole-path artifacts (``node_modules`` / ``.gitignore``): absolute-target
      symlink, skip if destination or source already exists / is missing.
    - ``.pi``: :func:`mirror_pi_untracked` —— 逐条镜像 git 未跟踪条目，
      整目录 symlink 只作为非 git / 空 ``.pi`` 的退化路径。
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

    mirror_pi_untracked(ctx)


def run_clean_defaults(ctx: WorktreeContext) -> None:
    """Remove symlinks that ``run_presetup_defaults`` created.

    Strategy:
    - Only remove symlinks (``os.path.islink``), never regular files or
      directories — safe against accidental deletion.
    - ``.pi`` 已不在 ``DEFAULT_ARTIFACTS``（现在逐条目镜像），但旧版本留下的整目录
      symlink 仍要回收：显式处理，然后走 :func:`unmirror_pi_untracked`。
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

    pi_path = os.path.join(ctx.worktree_path, PI_DIR)
    if os.path.islink(pi_path):
        os.unlink(pi_path)
        print(f"  [ok] removed symlink {PI_DIR}", file=sys.stderr)
        return

    unmirror_pi_untracked(ctx)
