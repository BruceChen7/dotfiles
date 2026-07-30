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


def run_presetup_defaults(ctx: WorktreeContext) -> None:
    """Symlink default artifacts from *source_repo* into *worktree_path*.

    Strategy:
    - Use absolute-path symlinks (worktree may be at a different directory level).
    - Skip if destination already exists (file, dir, or symlink).
    - Skip if source artifact does not exist.
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


def run_clean_defaults(ctx: WorktreeContext) -> None:
    """Remove symlinks that ``run_presetup_defaults`` created.

    Strategy:
    - Only remove symlinks (``os.path.islink``), never regular files or
      directories — safe against accidental deletion.
    - Silently skip non-symlink paths.
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
