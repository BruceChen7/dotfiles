"""Tests for built-in default behaviors (symlink / clean)."""

from __future__ import annotations

import os
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
