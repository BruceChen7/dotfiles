"""Tests for built-in default behaviors (symlink / clean)."""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest

from worktree_hooks.ctx import WorktreeContext
from worktree_hooks.defaults import (
    DEFAULT_ARTIFACTS,
    run_clean_defaults,
    run_presetup_defaults,
)


class TestDefaultsPresetup(unittest.TestCase):
    """run_presetup_defaults: symlink artifacts into worktree."""

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

        self.assertEqual(os.path.realpath(existing_link), os.path.realpath(dummy_target))

    def test_skip_missing_source(self) -> None:
        """If a source artifact does not exist, skip silently."""
        extra_artifact = "some-extra-file"
        os.remove(os.path.join(self.source, ".gitignore"))

        # Manually extend for this test
        orig = DEFAULT_ARTIFACTS[:]
        try:
            DEFAULT_ARTIFACTS.append(extra_artifact)
            # The plan uses a hardcoded list; this test just ensures missing source
            # doesn't crash. .gitignore was removed so it should be skipped.
            run_presetup_defaults(self.ctx)
            # extra_artifact doesn't exist in source — should skip
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


class TestDefaultsMergePiDirs(unittest.TestCase):
    """run_presetup_defaults: merge the repo-level skill farm into tracked `.pi`.

    Fixture mirrors the real layout: `verify`-style tracked skill dirs follow the
    branch, while skill-toggle's farm entries are symlinks into a shared library
    outside the repo. Only the symlink entries may cross into the worktree.
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        base = self._tmp.name
        self.source = os.path.join(base, "source")
        self.worktree = os.path.join(base, "worktree")
        self.library = os.path.join(base, "library")
        os.makedirs(os.path.join(self.library, "alpha"))
        os.makedirs(os.path.join(self.source, ".pi", "skills"))
        os.makedirs(os.path.join(self.source, ".pi", "disabled-skills"))
        os.makedirs(os.path.join(self.worktree, ".pi", "skills"))

        # 主 checkout：tracked skill（真目录）+ farm 链接（symlink）+ 关掉的标记（文件）
        os.makedirs(os.path.join(self.source, ".pi", "skills", "tracked"))
        self.farm_source = os.path.join(self.source, ".pi", "skills", "alpha")
        os.symlink(
            os.path.join(self.library, "alpha"),
            self.farm_source,
        )
        self.disabled_source = os.path.join(
            self.source, ".pi", "disabled-skills", "opencli-browser"
        )
        with open(self.disabled_source, "w"):
            pass

        # worktree：只带 tracked 的那一个
        self.tracked_dst = os.path.join(self.worktree, ".pi", "skills", "tracked")
        os.makedirs(self.tracked_dst)

        self.ctx = WorktreeContext(
            source_repo=self.source,
            worktree_path=self.worktree,
            verbose=False,
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _farm_dst(self) -> str:
        return os.path.join(self.worktree, ".pi", "skills", "alpha")

    def _disabled_dst(self) -> str:
        return os.path.join(self.worktree, ".pi", "disabled-skills", "opencli-browser")

    def test_merge_skill_farm_into_existing_pi_dir(self) -> None:
        """Farm symlinks are mirrored with the same target."""
        run_presetup_defaults(self.ctx)

        dst = self._farm_dst()
        self.assertTrue(os.path.islink(dst), "farm entry should be mirrored")
        self.assertEqual(os.readlink(dst), os.readlink(self.farm_source))
        self.assertTrue(os.path.isdir(dst), "mirrored link should resolve")

    def test_merge_keeps_tracked_pi_entry(self) -> None:
        """A tracked skill dir in the worktree is never replaced by a link."""
        run_presetup_defaults(self.ctx)

        self.assertFalse(os.path.islink(self.tracked_dst))
        self.assertTrue(os.path.isdir(self.tracked_dst))

    def test_merge_skips_real_source_entries(self) -> None:
        """Real dirs/files in the source skills dir follow the branch, not symlinks."""
        run_presetup_defaults(self.ctx)

        self.assertFalse(
            os.path.lexists(os.path.join(self.worktree, ".pi", "skills", "tracked.link")),
            "no extra entry should appear for tracked skills",
        )
        self.assertEqual(
            sorted(os.listdir(os.path.join(self.worktree, ".pi", "skills"))),
            ["alpha", "tracked"],
        )

    def test_merge_disabled_skill_markers(self) -> None:
        """`.pi/disabled-skills` entries are mirrored too, so toggles carry over."""
        run_presetup_defaults(self.ctx)

        dst = self._disabled_dst()
        self.assertTrue(os.path.islink(dst), "disabled marker should be mirrored")
        self.assertEqual(os.readlink(dst), self.disabled_source)

    def test_merge_is_idempotent(self) -> None:
        """Second presetup adds nothing and leaves the mirrored link alone."""
        run_presetup_defaults(self.ctx)
        first = os.readlink(self._farm_dst())

        run_presetup_defaults(self.ctx)

        self.assertEqual(os.readlink(self._farm_dst()), first)
        self.assertEqual(
            sorted(os.listdir(os.path.join(self.worktree, ".pi", "skills"))),
            ["alpha", "tracked"],
        )
        self.assertEqual(
            sorted(os.listdir(os.path.join(self.worktree, ".pi", "disabled-skills"))),
            ["opencli-browser"],
        )

    def test_merge_skips_when_source_dir_missing(self) -> None:
        """No `.pi/skills` in the source (plain project) is a silent no-op."""
        shutil.rmtree(os.path.join(self.source, ".pi", "skills"))

        run_presetup_defaults(self.ctx)

        self.assertEqual(
            sorted(os.listdir(os.path.join(self.worktree, ".pi", "skills"))),
            ["tracked"],
        )

    def test_merge_does_not_create_empty_dir(self) -> None:
        """An empty source dir (fresh `.pi/disabled-skills`) creates nothing."""
        os.remove(self.disabled_source)
        self.assertEqual(
            os.listdir(os.path.join(self.source, ".pi", "disabled-skills")), []
        )

        run_presetup_defaults(self.ctx)

        self.assertFalse(
            os.path.exists(os.path.join(self.worktree, ".pi", "disabled-skills"))
        )

    def test_merge_leaves_whole_pi_symlink_alone(self) -> None:
        """When `.pi` itself is a symlink, merge does not add anything inside."""
        other = os.path.join(self._tmp.name, "other-worktree")
        os.makedirs(other)
        ctx = WorktreeContext(
            source_repo=self.source, worktree_path=other, verbose=False
        )

        run_presetup_defaults(ctx)

        pi_dst = os.path.join(other, ".pi")
        self.assertTrue(os.path.islink(pi_dst), ".pi should be one symlink")
        self.assertEqual(
            sorted(os.listdir(os.path.join(pi_dst, "skills"))),
            ["alpha", "tracked"],
        )


class TestDefaultsMergeClean(unittest.TestCase):
    """run_clean_defaults: only the mirrored links go away."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        base = self._tmp.name
        self.source = os.path.join(base, "source")
        self.worktree = os.path.join(base, "worktree")
        self.library = os.path.join(base, "library")
        os.makedirs(os.path.join(self.library, "alpha"))
        os.makedirs(os.path.join(self.source, ".pi", "skills"))
        os.makedirs(
            os.path.join(self.worktree, ".pi", "skills", "tracked")
        )
        self.farm_source = os.path.join(self.source, ".pi", "skills", "alpha")
        os.symlink(os.path.join(self.library, "alpha"), self.farm_source)

        self.ctx = WorktreeContext(
            source_repo=self.source,
            worktree_path=self.worktree,
            verbose=False,
        )
        run_presetup_defaults(self.ctx)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_clean_removes_only_mirrored_links(self) -> None:
        """Mirrored farm links disappear; tracked dirs and foreign links stay."""
        foreign_target = os.path.join(self._tmp.name, "elsewhere")
        os.makedirs(foreign_target)
        foreign = os.path.join(self.worktree, ".pi", "skills", "foreign")
        os.symlink(foreign_target, foreign)

        run_clean_defaults(self.ctx)

        self.assertFalse(
            os.path.lexists(os.path.join(self.worktree, ".pi", "skills", "alpha"))
        )
        self.assertTrue(
            os.path.isdir(os.path.join(self.worktree, ".pi", "skills", "tracked"))
        )
        self.assertTrue(os.path.islink(foreign))
