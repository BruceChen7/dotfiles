"""Worktree context data type."""

from __future__ import annotations

import dataclasses
from typing import Optional


@dataclasses.dataclass
class WorktreeContext:
    """Context passed to default behaviors and plugin hooks.

    Attributes:
        source_repo:   Absolute path to the source repository root.
        worktree_path: Absolute path to the worktree directory.
        worktree_name: Last component of worktree_path (e.g. "scXX").
        verbose:       Whether verbose output is enabled.
    """

    source_repo: str
    worktree_path: str
    worktree_name: str = ""
    verbose: bool = False

    def __post_init__(self) -> None:
        if not self.worktree_name:
            self.worktree_name = (
                self.worktree_path.rstrip("/").rsplit("/", 1)[-1]
            )
