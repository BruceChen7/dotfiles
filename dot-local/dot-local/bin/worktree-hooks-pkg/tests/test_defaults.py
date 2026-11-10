"""Tests for built-in default behaviors (`.pi` mirror / symlink / clean)."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest

from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.defaults import (
    DEFAULT_ARTIFACTS,
    LINK,
    SKIP,
    TRUNK_MKDIR,
    TRUNK_NOOP,
    classify_entry,
    entry_link_target,
    run_clean_defaults,
    run_presetup_defaults,
    untracked_entries,
)

GIT_TIMEOUT = 10


def _git(repo: str, *args: str) -> None:
    """在 *repo* 里跑一条 git 命令。

    固定 ``init.defaultBranch=main``，避免机器上的全局 init 配置改变分支名；
    每个 repo 都在 :func:`_init_repo` 里单独设 ``user.*``，不读全局身份。
    """
    subprocess.run(
        ["git", "-c", "init.defaultBranch=main", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
        timeout=GIT_TIMEOUT,
    )


def _init_repo(repo: str) -> None:
    os.makedirs(repo, exist_ok=True)
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "test@example.com")
    _git(repo, "config", "user.name", "Test")


def _commit_paths(repo: str, *paths: str) -> None:
    """只提交指定路径：其余文件保持未跟踪，正是本组测试要的形状。"""
    _git(repo, "add", "--", *paths)
    _git(repo, "commit", "-q", "-m", "init")


def _write(path: str, content: str = "") -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(content)


def _symlink_map(root: str) -> dict:
    """收集 *root* 下全部 symlink：相对路径 → readlink 原值（不解析）。"""
    links: dict = {}
    for dirpath, dirnames, filenames in os.walk(root):
        for name in dirnames + filenames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                links[os.path.relpath(path, root)] = os.readlink(path)
    return links


class TestClassifyEntry(unittest.TestCase):
    """classify_entry 是纯查表：不碰文件系统，四个分支逐一对齐。"""

    def test_trunk_when_pi_exists_is_noop(self) -> None:
        # trunk 只保证目录存在；已存在时绝不能换成整目录 symlink
        self.assertEqual(
            classify_entry("", wt_pi_exists=True, dst_lexists=False),
            TRUNK_NOOP,
        )
        self.assertEqual(
            classify_entry(".", wt_pi_exists=True, dst_lexists=False),
            TRUNK_NOOP,
        )

    def test_trunk_when_pi_missing_needs_mkdir(self) -> None:
        # 缺目录时只建真目录，不能滑向 LINK（整目录 symlink）
        self.assertEqual(
            classify_entry("", wt_pi_exists=False, dst_lexists=False),
            TRUNK_MKDIR,
        )

    def test_existing_destination_is_skipped(self) -> None:
        # 目标已存在（tracked 或上次镜像）时绝不覆盖，这是幂等的来源
        self.assertEqual(
            classify_entry("plans", wt_pi_exists=True, dst_lexists=True),
            SKIP,
        )

    def test_missing_entry_is_linked(self) -> None:
        self.assertEqual(
            classify_entry("plans", wt_pi_exists=True, dst_lexists=False),
            LINK,
        )
        # `.pi` 还不存在也不影响：LINK 分支会先建父目录
        self.assertEqual(
            classify_entry("lessons.md", wt_pi_exists=False, dst_lexists=False),
            LINK,
        )


class TestEntryLinkTarget(unittest.TestCase):
    """entry_link_target 指向源条目自身，而不是它 readlink 出去的目标。"""

    def test_points_at_source_entry_itself(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source_pi = os.path.join(tmp, "repo", ".pi")
            library = os.path.join(tmp, "library")
            os.makedirs(library)
            os.makedirs(os.path.join(source_pi, "skills"))
            entry = os.path.join(source_pi, "skills", "how")
            os.symlink(library, entry)

            target = entry_link_target(source_pi, "skills/how")
            # 源条目是 symlink 时，目标仍是源条目路径本身……
            self.assertEqual(target, entry)
            # ……而不是它解析出的 library：source 重新指向时 worktree 要自动跟随
            self.assertNotEqual(target, os.path.realpath(entry))

    def test_returns_absolute_path(self) -> None:
        target = entry_link_target("relative/repo/.pi", "plans")
        self.assertTrue(os.path.isabs(target))
        self.assertTrue(target.endswith(os.path.join("repo", ".pi", "plans")))


class TestUntrackedEntries(unittest.TestCase):
    """untracked_entries 以真实 git repo 验证：候选 == 该镜像的条目。"""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.repo = os.path.join(self._tmp.name, "repo")

    def test_partial_tracked_repo_lists_only_untracked(self) -> None:
        """部分跟踪：tracked 路径不进候选；未跟踪项（含 ignored）逐条列出。"""
        _write(os.path.join(self.repo, ".pi", "skills", "tracked", "s.md"), "s\n")
        _write(os.path.join(self.repo, ".pi", "plans", "p.md"), "p\n")
        _write(os.path.join(self.repo, ".pi", "loose.md"), "l\n")
        _write(os.path.join(self.repo, ".gitignore"), ".pi/plans/\n")
        _init_repo(self.repo)
        _commit_paths(self.repo, ".gitignore", ".pi/skills/tracked/s.md")

        # plans/ 被 --directory 折叠成一条；tracked 的 skills/tracked 完全不出现
        self.assertEqual(
            set(untracked_entries(self.repo)), {"plans", "loose.md"}
        )

    def test_whole_pi_ignored_yields_trunk(self) -> None:
        """.pi 整体未跟踪时 git 只给一条 trunk（""），镜像走「真目录」分支。"""
        _write(os.path.join(self.repo, ".pi", "lessons.md"), "l\n")
        _write(os.path.join(self.repo, ".pi", "plans", "p.md"), "p\n")
        _write(os.path.join(self.repo, ".gitignore"), "/.pi/\n")
        _init_repo(self.repo)
        _commit_paths(self.repo, ".gitignore")

        self.assertEqual(untracked_entries(self.repo), [""])

    def test_non_git_dir_returns_empty(self) -> None:
        """非 git 目录交给退化路径，git 报错不得冒泡成异常。"""
        _write(os.path.join(self.repo, ".pi", "x.md"), "x\n")
        self.assertEqual(untracked_entries(self.repo), [])


class TestDefaultsPiPresetup(unittest.TestCase):
    """presetup 的 `.pi` 逐条目镜像（真实 git repo，不用 mock）。"""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.source = os.path.join(self._tmp.name, "source")
        self.worktree = os.path.join(self._tmp.name, "worktree")
        os.makedirs(self.worktree)

    def _ctx(self) -> WorktreeContext:
        return WorktreeContext(
            source_repo=self.source, worktree_path=self.worktree, verbose=False
        )

    def test_tracked_stays_real_and_untracked_is_mirrored(self) -> None:
        """tracked 路径留在本分支；未跟踪条目链接到源条目自身。"""
        _write(os.path.join(self.source, ".pi", "skills", "tracked", "s.md"), "b\n")
        _write(os.path.join(self.source, ".pi", "plans", "p.md"), "p\n")
        _write(os.path.join(self.source, ".gitignore"), ".pi/plans/\n")
        _init_repo(self.source)
        _commit_paths(self.source, ".gitignore", ".pi/skills/tracked/s.md")

        # 模拟 worktree checkout：tracked 文件已经以普通文件落地
        _write(os.path.join(self.worktree, ".pi", "skills", "tracked", "s.md"), "b\n")

        run_presetup_defaults(self._ctx())

        wt_pi = os.path.join(self.worktree, ".pi")
        # `.pi` 是真目录：整目录 symlink 会让 worktree 写操作落到主 checkout
        self.assertFalse(os.path.islink(wt_pi))
        self.assertTrue(os.path.isdir(wt_pi))
        tracked_dst = os.path.join(wt_pi, "skills", "tracked", "s.md")
        self.assertFalse(os.path.islink(tracked_dst))
        with open(tracked_dst) as fh:
            self.assertEqual(fh.read(), "b\n")
        plans_dst = os.path.join(wt_pi, "plans")
        self.assertTrue(os.path.islink(plans_dst))
        self.assertEqual(
            os.readlink(plans_dst),
            os.path.join(self.source, ".pi", "plans"),
            "链接应指向源条目自身而不是它的 readlink 目标",
        )

    def test_mirrored_link_does_not_copy_readlink_target(self) -> None:
        """源条目本身是 symlink：镜像指向源条目，而不是它穿过去的目录。"""
        library = os.path.join(self._tmp.name, "library")
        os.makedirs(library)
        source_link = os.path.join(self.source, ".pi", "skills", "how")
        os.makedirs(os.path.dirname(source_link))
        os.symlink(library, source_link)
        # tracked 兄弟节点让 `.pi/skills` 成为混合目录，git 才会单列出 `how`
        _write(os.path.join(self.source, ".pi", "skills", "tracked.md"), "t\n")
        _write(os.path.join(self.source, "README.md"), "x\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md", ".pi/skills/tracked.md")

        run_presetup_defaults(self._ctx())

        dst = os.path.join(self.worktree, ".pi", "skills", "how")
        self.assertTrue(os.path.islink(dst))
        self.assertEqual(os.readlink(dst), source_link)
        # 解析后仍能到达 library，说明镜像的是同一条链而不是复制它的目标
        self.assertEqual(os.path.realpath(dst), os.path.realpath(library))

    def test_presetup_is_idempotent(self) -> None:
        """二次 presetup 不新建、不重指任何链接（plan 的幂等判据）。"""
        _write(os.path.join(self.source, ".pi", "plans", "p.md"), "p\n")
        _write(os.path.join(self.source, ".pi", "loose.md"), "l\n")
        _write(os.path.join(self.source, "README.md"), "x\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md")

        run_presetup_defaults(self._ctx())
        first = _symlink_map(os.path.join(self.worktree, ".pi"))
        self.assertEqual(set(first), {"plans", "loose.md"})

        run_presetup_defaults(self._ctx())

        # 集合与每个 readlink 都逐字节不变，才算幂等
        self.assertEqual(_symlink_map(os.path.join(self.worktree, ".pi")), first)

    def test_trunk_shape_matches_source_top_level(self) -> None:
        """dotfiles 形状（`.pi` 整体未跟踪）：真目录 + 顶层逐条同名链接。"""
        _write(os.path.join(self.source, ".pi", "lessons.md"), "l\n")
        _write(os.path.join(self.source, ".pi", "plans", "p.md"), "p\n")
        _write(os.path.join(self.source, ".pi", "skills", "s", "SKILL.md"), "k\n")
        _write(os.path.join(self.source, ".gitignore"), "/.pi/\n")
        _init_repo(self.source)
        _commit_paths(self.source, ".gitignore")

        run_presetup_defaults(self._ctx())

        src_pi = os.path.join(self.source, ".pi")
        wt_pi = os.path.join(self.worktree, ".pi")
        self.assertFalse(os.path.islink(wt_pi), "trunk 也必须是真目录")
        self.assertTrue(os.path.isdir(wt_pi))
        # plan Goal 判据：worktree `.pi` 顶层 == 主 checkout `.pi` 顶层
        self.assertEqual(sorted(os.listdir(wt_pi)), sorted(os.listdir(src_pi)))
        for name in os.listdir(src_pi):
            self.assertTrue(os.path.islink(os.path.join(wt_pi, name)))

    def test_empty_untracked_dir_is_mirrored(self) -> None:
        """空目录也是候选：混合 `.pi` 里 git 会给 `.pi/empty-dir/` 一条。

        空目录没内容，但名字必须可见，否则「worktree 可见内容 == 主 checkout」
        的 plan 判据在目录粒度上就破了。
        """
        _write(os.path.join(self.source, ".pi", "skills", "tracked.md"), "t\n")
        os.makedirs(os.path.join(self.source, ".pi", "empty-dir"))
        _write(os.path.join(self.source, "README.md"), "x\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md", ".pi/skills/tracked.md")

        # 模拟 checkout：tracked 文件在 worktree 里已以普通文件落地
        _write(os.path.join(self.worktree, ".pi", "skills", "tracked.md"), "t\n")

        run_presetup_defaults(self._ctx())

        src_pi = os.path.join(self.source, ".pi")
        wt_pi = os.path.join(self.worktree, ".pi")
        empty = os.path.join(wt_pi, "empty-dir")
        self.assertTrue(os.path.islink(empty), "空目录应镜像为 symlink")
        self.assertEqual(os.readlink(empty), os.path.join(src_pi, "empty-dir"))
        # plan Goal 判据：worktree `.pi` 顶层 == 源 `.pi` 顶层（含空目录名）
        self.assertEqual(sorted(os.listdir(wt_pi)), sorted(os.listdir(src_pi)))

    def test_trunk_shape_presetup_twice_is_stable(self) -> None:
        """trunk 形状二次 presetup：条目名与 readlink 快照完全一致。"""
        _write(os.path.join(self.source, ".pi", "a.md"), "a\n")
        _write(os.path.join(self.source, ".pi", "dir", "d.md"), "d\n")
        _write(os.path.join(self.source, ".gitignore"), "/.pi/\n")
        _init_repo(self.source)
        _commit_paths(self.source, ".gitignore")

        run_presetup_defaults(self._ctx())
        wt_pi = os.path.join(self.worktree, ".pi")
        first_names = sorted(os.listdir(wt_pi))
        first_links = _symlink_map(wt_pi)

        run_presetup_defaults(self._ctx())

        # 第二次不得新建/重指任何链接：名字集合与每个 readlink 逐字节不变
        self.assertEqual(first_names, ["a.md", "dir"])
        self.assertEqual(sorted(os.listdir(wt_pi)), first_names)
        self.assertEqual(_symlink_map(wt_pi), first_links)

    def test_non_git_source_falls_back_to_whole_dir_symlink(self) -> None:
        """非 git 源无候选：退化路径保持旧行为（`.pi` 整目录 symlink）。"""
        _write(os.path.join(self.source, ".pi", "only.md"), "o\n")

        run_presetup_defaults(self._ctx())

        wt_pi = os.path.join(self.worktree, ".pi")
        self.assertTrue(os.path.islink(wt_pi))
        self.assertEqual(os.readlink(wt_pi), os.path.join(self.source, ".pi"))

    def test_no_source_pi_creates_nothing(self) -> None:
        """源没有 `.pi`：候选为空且无退化对象，不得凭空建目录。"""
        _write(os.path.join(self.source, "README.md"), "x\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md")

        run_presetup_defaults(self._ctx())

        self.assertFalse(os.path.lexists(os.path.join(self.worktree, ".pi")))


class TestDefaultsPiClean(unittest.TestCase):
    """clean 只回收 presetup 建的镜像链接（含嵌套），tracked/外来物不碰。"""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.source = os.path.join(self._tmp.name, "source")
        self.worktree = os.path.join(self._tmp.name, "worktree")
        os.makedirs(self.worktree)

    def _ctx(self) -> WorktreeContext:
        return WorktreeContext(
            source_repo=self.source, worktree_path=self.worktree, verbose=False
        )

    def test_clean_removes_mirrored_nested_and_top_level_links(self) -> None:
        library = os.path.join(self._tmp.name, "library")
        os.makedirs(library)
        _write(os.path.join(self.source, "README.md"), "x\n")
        os.makedirs(os.path.join(self.source, ".pi", "skills"))
        os.symlink(library, os.path.join(self.source, ".pi", "skills", "how"))
        _write(os.path.join(self.source, ".pi", "plans", "p.md"), "p\n")
        _write(os.path.join(self.source, ".pi", "loose.md"), "l\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md")

        # worktree 侧的本地内容：tracked 文件、普通目录、外来链接
        wt_pi = os.path.join(self.worktree, ".pi")
        _write(os.path.join(wt_pi, "tracked.md"), "t\n")
        os.makedirs(os.path.join(wt_pi, "realdir"))
        elsewhere = os.path.join(self._tmp.name, "elsewhere")
        os.makedirs(elsewhere)
        foreign = os.path.join(wt_pi, "foreign")
        os.symlink(elsewhere, foreign)

        run_presetup_defaults(self._ctx())
        self.assertTrue(os.path.islink(os.path.join(wt_pi, "skills", "how")))
        self.assertTrue(os.path.islink(os.path.join(wt_pi, "plans")))

        run_clean_defaults(self._ctx())

        # 顶层与嵌套镜像链接都回收（嵌套只可能经候选集扫到）
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "plans")))
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "loose.md")))
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "skills", "how")))
        # tracked 文件、真目录、外来链接必须留下（clean 只删自己建的）
        self.assertTrue(os.path.isfile(os.path.join(wt_pi, "tracked.md")))
        self.assertTrue(os.path.isdir(os.path.join(wt_pi, "realdir")))
        self.assertTrue(os.path.islink(foreign))
        self.assertEqual(os.readlink(foreign), elsewhere)

    def _init_mixed_skills_repo(self) -> None:
        """`.pi/skills` 混合形状：tracked.md 已提交、orphan.md 未跟踪。"""
        _write(os.path.join(self.source, ".pi", "skills", "tracked.md"), "t\n")
        _write(os.path.join(self.source, ".pi", "skills", "orphan.md"), "o\n")
        _write(os.path.join(self.source, "README.md"), "x\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md", ".pi/skills/tracked.md")

    def test_clean_recovers_nested_orphan_after_source_deleted(self) -> None:
        """源条目删除后，`skills/orphan.md` 嵌套链仍要回收。

        候选集是**当前** git 视图：源文件一删，orphan 就不在候选里了，只能靠
        第二道递归兜底扫到；否则 worktree 会永远留着指向虚无的死链。
        """
        self._init_mixed_skills_repo()
        wt_pi = os.path.join(self.worktree, ".pi")
        _write(os.path.join(wt_pi, "skills", "tracked.md"), "t\n")

        run_presetup_defaults(self._ctx())
        orphan = os.path.join(wt_pi, "skills", "orphan.md")
        self.assertTrue(os.path.islink(orphan))

        os.unlink(os.path.join(self.source, ".pi", "skills", "orphan.md"))
        run_clean_defaults(self._ctx())

        self.assertFalse(os.path.lexists(orphan))
        # tracked 真文件属于本分支，必须仍在
        self.assertTrue(
            os.path.isfile(os.path.join(wt_pi, "skills", "tracked.md"))
        )

    def test_clean_keeps_user_files_and_foreign_links(self) -> None:
        """归属校验必须严格：用户普通文件、外来链接一律不动（真断言）。"""
        self._init_mixed_skills_repo()
        wt_pi = os.path.join(self.worktree, ".pi")
        _write(os.path.join(wt_pi, "skills", "tracked.md"), "t\n")
        _write(os.path.join(wt_pi, "mine.txt"), "mine\n")
        elsewhere = os.path.join(self._tmp.name, "elsewhere")
        os.makedirs(elsewhere)
        foreign = os.path.join(wt_pi, "foreign")
        os.symlink(elsewhere, foreign)

        run_presetup_defaults(self._ctx())
        os.unlink(os.path.join(self.source, ".pi", "skills", "orphan.md"))
        run_clean_defaults(self._ctx())

        # 用户普通文件：内容与类型原样保留
        mine = os.path.join(wt_pi, "mine.txt")
        self.assertFalse(os.path.islink(mine))
        with open(mine) as fh:
            self.assertEqual(fh.read(), "mine\n")
        # 外来链接：既不删也不重指
        self.assertTrue(os.path.islink(foreign))
        self.assertEqual(os.readlink(foreign), elsewhere)
        self.assertEqual(os.path.realpath(foreign), os.path.realpath(elsewhere))
        # tracked 普通文件不得被当成镜像链误删
        tracked = os.path.join(wt_pi, "skills", "tracked.md")
        self.assertFalse(os.path.islink(tracked))
        self.assertTrue(os.path.isfile(tracked))

    def test_clean_keeps_foreign_relative_link(self) -> None:
        """外来相对链接不得误删：解析按链接所在目录，而非进程 CWD。"""
        self._init_mixed_skills_repo()
        wt_pi = os.path.join(self.worktree, ".pi")
        _write(os.path.join(wt_pi, "skills", "tracked.md"), "t\n")

        run_presetup_defaults(self._ctx())
        # 父目录 skills/ 是真目录；目标是 link 所在目录相对的 `../../elsewhere`
        elsewhere = os.path.join(self.worktree, "elsewhere")
        os.makedirs(elsewhere)
        rel_link = os.path.join(wt_pi, "skills", "relative-foreign")
        os.symlink(os.path.join("..", "..", "elsewhere"), rel_link)

        os.unlink(os.path.join(self.source, ".pi", "skills", "orphan.md"))
        run_clean_defaults(self._ctx())

        self.assertTrue(os.path.islink(rel_link))
        self.assertEqual(
            os.readlink(rel_link), os.path.join("..", "..", "elsewhere")
        )
        self.assertEqual(os.path.realpath(rel_link), os.path.realpath(elsewhere))

    def test_clean_matches_alias_path_target(self) -> None:
        """链接目标是路径别名（先 symlink 到源仓库）时仍按 realpath 回收。"""
        _write(os.path.join(self.source, ".pi", "loose.md"), "l\n")
        _write(os.path.join(self.source, "README.md"), "x\n")
        _init_repo(self.source)
        _commit_paths(self.source, "README.md")

        alias = os.path.join(self._tmp.name, "link-to-source")
        os.symlink(self.source, alias)
        wt_pi = os.path.join(self.worktree, ".pi")
        os.makedirs(wt_pi)
        dst = os.path.join(wt_pi, "loose.md")
        os.symlink(os.path.join(alias, ".pi", "loose.md"), dst)

        run_clean_defaults(self._ctx())

        self.assertFalse(os.path.lexists(dst))
        # 只回收链接，`.pi` 目录本身保留
        self.assertTrue(os.path.isdir(wt_pi))

    def test_clean_trunk_shape_keeps_dir_and_is_idempotent(self) -> None:
        """trunk 形状：镜像链接全回收，但 `.pi` 目录本身必须留下。"""
        _write(os.path.join(self.source, ".pi", "a.md"), "a\n")
        _write(os.path.join(self.source, ".pi", "b", "c.md"), "c\n")
        _write(os.path.join(self.source, ".gitignore"), "/.pi/\n")
        _init_repo(self.source)
        _commit_paths(self.source, ".gitignore")

        run_presetup_defaults(self._ctx())
        wt_pi = os.path.join(self.worktree, ".pi")
        self.assertTrue(os.path.islink(os.path.join(wt_pi, "a.md")))
        self.assertTrue(os.path.islink(os.path.join(wt_pi, "b")))

        run_clean_defaults(self._ctx())

        # 顶层镜像链接逐个回收（含目录条目）
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "a.md")))
        self.assertFalse(os.path.lexists(os.path.join(wt_pi, "b")))
        # 目录本身不删：clean 无法区分它是 presetup 建的还是用户自己建的，
        # 且空目录不阻塞 `git worktree remove`（plan 的 clean 语义）
        self.assertTrue(os.path.isdir(wt_pi))
        self.assertFalse(os.path.islink(wt_pi))

        # 二次 clean 幂等：链接已不在，不得抛异常
        run_clean_defaults(self._ctx())

    def test_clean_removes_legacy_whole_dir_symlink(self) -> None:
        """旧版本留下的 `.pi` 整目录 symlink 仍要能回收（向后兼容）。"""
        _write(os.path.join(self.source, ".pi", "x.md"), "x\n")
        wt_pi = os.path.join(self.worktree, ".pi")
        os.symlink(os.path.join(self.source, ".pi"), wt_pi)

        run_clean_defaults(self._ctx())

        self.assertFalse(os.path.lexists(wt_pi))
        run_clean_defaults(self._ctx())  # 幂等


class TestDefaultsPresetup(unittest.TestCase):
    """run_presetup_defaults: whole-path artifacts (node_modules/.gitignore)."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "source")
        self.worktree = os.path.join(self._tmp.name, "worktree")
        os.mkdir(self.source)
        os.mkdir(self.worktree)

        # Create source artifacts
        os.mkdir(os.path.join(self.source, ".pi"))
        os.mkdir(os.path.join(self.source, "node_modules"))
        with open(os.path.join(self.source, ".gitignore"), "w") as f:
            f.write("*.pyc\n")

        self.ctx = WorktreeContext(
            source_repo=self.source,
            worktree_path=self.worktree,
            verbose=False,
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_symlinks_created(self) -> None:
        """All default artifacts should be symlinked into the worktree."""
        run_presetup_defaults(self.ctx)

        for artifact in DEFAULT_ARTIFACTS:
            dst = os.path.join(self.worktree, artifact)
            self.assertTrue(
                os.path.islink(dst), f"{artifact} should be a symlink"
            )
            src = os.path.join(self.source, artifact)
            self.assertEqual(
                os.path.realpath(dst),
                os.path.realpath(src),
                f"{artifact} should point to source",
            )
        # 非 git 源 + 空 `.pi`：退化路径仍是整目录 symlink（行为不变）
        self.assertTrue(os.path.islink(os.path.join(self.worktree, ".pi")))

    def test_skip_existing(self) -> None:
        """If destination already exists, do not overwrite."""
        existing_file = os.path.join(self.worktree, ".gitignore")
        with open(existing_file, "w") as f:
            f.write("original\n")

        run_presetup_defaults(self.ctx)

        with open(existing_file) as f:
            self.assertEqual(f.read(), "original\n")

    def test_skip_existing_symlink(self) -> None:
        """If destination is already a symlink, skip it."""
        dummy_target = os.path.join(self._tmp.name, "dummy")
        os.mkdir(dummy_target)
        existing_link = os.path.join(self.worktree, ".pi")
        os.symlink(dummy_target, existing_link)

        run_presetup_defaults(self.ctx)

        self.assertEqual(
            os.path.realpath(existing_link), os.path.realpath(dummy_target)
        )

    def test_skip_missing_source(self) -> None:
        """If a source artifact does not exist, skip silently."""
        extra_artifact = "some-extra-file"
        os.remove(os.path.join(self.source, ".gitignore"))

        # Manually extend for this test
        orig = DEFAULT_ARTIFACTS[:]
        try:
            DEFAULT_ARTIFACTS.append(extra_artifact)
            # .gitignore was removed; extra_artifact doesn't exist either.
            run_presetup_defaults(self.ctx)
            dst = os.path.join(self.worktree, extra_artifact)
            self.assertFalse(os.path.lexists(dst))
        finally:
            DEFAULT_ARTIFACTS[:] = orig


class TestDefaultsClean(unittest.TestCase):
    """run_clean_defaults: remove symlinks from worktree."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "source")
        self.worktree = os.path.join(self._tmp.name, "worktree")
        os.mkdir(self.source)
        os.mkdir(self.worktree)

        # Create source artifacts
        os.mkdir(os.path.join(self.source, ".pi"))
        os.mkdir(os.path.join(self.source, "node_modules"))
        with open(os.path.join(self.source, ".gitignore"), "w") as f:
            f.write("*.pyc\n")

        self.ctx = WorktreeContext(
            source_repo=self.source,
            worktree_path=self.worktree,
            verbose=False,
        )

        # Run presetup first so links exist
        run_presetup_defaults(self.ctx)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_symlinks_removed(self) -> None:
        """Clean should remove all symlinks created by presetup."""
        run_clean_defaults(self.ctx)

        for artifact in DEFAULT_ARTIFACTS:
            dst = os.path.join(self.worktree, artifact)
            self.assertFalse(os.path.islink(dst), f"{artifact} should be removed")
            self.assertFalse(os.path.exists(dst), f"{artifact} should not exist")
        # 旧版整目录 `.pi` symlink 的回收路径也必须生效
        self.assertFalse(
            os.path.lexists(os.path.join(self.worktree, ".pi"))
        )

    def test_only_symlinks_removed(self) -> None:
        """Clean should only remove symlinks, not regular files/dirs."""
        regular_file = os.path.join(self.worktree, "keep-me.txt")
        with open(regular_file, "w") as f:
            f.write("safe\n")
        regular_dir = os.path.join(self.worktree, "keep-dir")
        os.mkdir(regular_dir)

        run_clean_defaults(self.ctx)

        self.assertTrue(os.path.isfile(regular_file))
        self.assertTrue(os.path.isdir(regular_dir))

    def test_clean_twice_safe(self) -> None:
        """Running clean twice should be safe (no error on missing links)."""
        run_clean_defaults(self.ctx)
        # Second run: no links to remove, should not crash
        run_clean_defaults(self.ctx)


if __name__ == "__main__":
    unittest.main()
