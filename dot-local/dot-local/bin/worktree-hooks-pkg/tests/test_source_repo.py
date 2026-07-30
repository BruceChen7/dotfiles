"""Tests for source-repo auto-derivation."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest

from worktree_hooks.cli import resolve_source_repo


class TestSourceRepoResolution(unittest.TestCase):
    """resolve_source_repo: auto-derive source repo from worktree path."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.main_repo = os.path.join(self._tmp.name, "main")
        os.mkdir(self.main_repo)

        # Init a bare-like main repo (simulating a git repo with worktrees)
        subprocess.run(
            ["git", "init"],
            cwd=self.main_repo,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "config", "user.email", "test@test"],
            cwd=self.main_repo,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test"],
            cwd=self.main_repo,
            capture_output=True,
            timeout=10,
        )

        # Make an initial commit so worktree operations work
        readme = os.path.join(self.main_repo, "README.md")
        with open(readme, "w") as f:
            f.write("# test\n")
        subprocess.run(
            ["git", "add", "."],
            cwd=self.main_repo,
            capture_output=True,
            timeout=10,
        )
        subprocess.run(
            ["git", "commit", "-m", "initial"],
            cwd=self.main_repo,
            capture_output=True,
            timeout=10,
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_main_repo_returns_self(self) -> None:
        """When called on the main repo root, resolve to itself."""
        repo = resolve_source_repo(self.main_repo)
        self.assertEqual(os.path.realpath(repo), os.path.realpath(self.main_repo))

    def test_worktree_resolves_to_source(self) -> None:
        """A git worktree should resolve to the main repo."""
        worktree = os.path.join(self._tmp.name, "wt")
        # Do NOT pre-create the directory — git worktree add creates it.

        # Use --detach since the main branch is already checked out
        # in the main repo.
        subprocess.run(
            ["git", "worktree", "add", "--detach", worktree, "HEAD"],
            cwd=self.main_repo,
            capture_output=True,
            timeout=10,
            check=True,
        )

        repo = resolve_source_repo(worktree)
        self.assertIsNotNone(repo)
        self.assertEqual(
            os.path.realpath(repo),
            os.path.realpath(self.main_repo),
        )

    def test_non_git_dir_returns_none(self) -> None:
        """Outside a git repo, resolve_source_repo returns None."""
        with tempfile.TemporaryDirectory() as tmp:
            repo = resolve_source_repo(tmp)
            self.assertIsNone(repo)

    def test_explicit_args_skip_derivation(self) -> None:
        """When source_repo is explicitly given, derivation is not used.

        This is tested at the parse_args level. Here we just verify that
        resolve_source_repo still returns None for an unrelated path.
        """
        # The function itself doesn't handle explicit args — that's parse_args.
        # Just verify it returns None for a random non-git dir.
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(resolve_source_repo(tmp))
