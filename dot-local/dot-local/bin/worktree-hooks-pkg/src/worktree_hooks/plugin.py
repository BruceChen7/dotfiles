"""Plugin discovery and loading for worktree hooks.

Finds ``.pi/worktree-hooks/plugin.py`` inside the source repository and
loads it via duck-typing (no base class required).
"""

from __future__ import annotations

import importlib.util
import os
import sys
from types import ModuleType
from typing import Optional

from worktree_hooks.ctx import WorktreeContext

PLUGIN_RELPATH = os.path.join(".pi", "worktree-hooks", "plugin.py")


def resolve_plugin(source_repo: str) -> Optional[ModuleType]:
    """Discover and load the project plugin at ``source_repo``.

    Looks for ``<source_repo>/.pi/worktree-hooks/plugin.py``.

    Returns the loaded module, or *None* when no plugin exists.
    """
    plugin_path = os.path.join(source_repo, PLUGIN_RELPATH)

    if not os.path.isfile(plugin_path):
        return None

    spec = importlib.util.spec_from_file_location(
        "worktree_hooks_project_plugin", plugin_path,
    )
    if spec is None or spec.loader is None:
        return None

    module = importlib.util.module_from_spec(spec)
    # Temporarily add the plugin's directory to sys.path so relative
    # imports inside the plugin (if any) work as expected.
    plugin_dir = os.path.dirname(plugin_path)
    sys.path.insert(0, plugin_dir)
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path.remove(plugin_dir)

    return module


def call_plugin_hook(
    plugin: Optional[ModuleType],
    hook_name: str,
    ctx: WorktreeContext,
) -> None:
    """Call *hook_name* on *plugin* if the function exists.

    Silently no-ops when:
    - *plugin* is *None* (no plugin installed).
    - The plugin module does not define a function named *hook_name*.
    """
    if plugin is None:
        return

    hook = getattr(plugin, hook_name, None)
    if hook is None:
        return

    hook(ctx)
