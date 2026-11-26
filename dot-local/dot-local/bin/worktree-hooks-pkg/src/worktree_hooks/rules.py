"""声明式规则层：一张全局规则表取代「每个 repo 一份 ITEMS 表」。

为什么要有这一层：`worktree-deps.sh` 那种形状（每个项目一张 bash 清单 + 一个
`plugin.py` 把它们串起来）把「这个项目有哪些被 gitignore 的本地产物」写成了**代码**，
于是新增一个 repo 就要复制 100 行样板。但清单里的条目本身是**路径形状**而不是项目
事实 —— `node_modules`、`.nsh`、`env.local` 在哪都是同一件事，只是位置不同。所以这里
把判据写成「相对仓库根的 glob」，内置在工具里：

    **/node_modules   → node_modules（源里没有就 npm ci；落后于清单就地重装）
    **/.nsh           → linkdir（目录本身是真目录，子项逐个链；test/test-logs 不链）
    **/env.local      → link
    .gitignore        → link

覆盖顺序（先命中先得）：仓库级 `.pi/worktree-hooks.toml` → 全局
`~/.config/worktree-hooks/config.toml` → 上面这张内置表。仓库级只需要在**真的和全局
不一样**时才存在；pi-clients 这种项目一个文件都不用写。

本模块的分层（Functional Core, Imperative Shell）：

- 纯函数：:func:`decide`（四个布尔 → 一个动作）、:func:`plan`、
  :func:`parse_rules`（toml 字典 → Rule 列表）、:func:`format_action`。
- 壳：:func:`discover`（走目录找候选）、:func:`inspect`（问文件系统要布尔）、
  :func:`apply` / :func:`clean`（动磁盘、跑 npm）。
"""

from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

# ---- 动作与种类 -----------------------------------------------------------

LINK = "link"
LINKDIR = "linkdir"
NODE_MODULES = "node_modules"
KINDS: Tuple[str, ...] = (LINK, LINKDIR, NODE_MODULES)

SKIP = "skip"
LINK_ACTION = "link"
LINKDIR_ACTION = "linkdir"
INSTALL = "install"
REINSTALL = "reinstall"
WARN = "warn"

# 走目录时的深度上限：`apps/a/packages/b/node_modules` 这类 monorepo 也够用，
# 又不至于在深目录里翻个没完（presetup 在 herdr 建 workspace 的路径上）。
MAX_DEPTH = 12

WALK_SKIP = {".git", ".hg", ".svn"}


@dataclass(frozen=True)
class Rule:
    """一条「路径形状 → 补法」的声明。

    ``match``：相对仓库根的 glob。支持两种形态 ——
    ``**/<name>``（任意深度下恰好叫这个名的条目）与字面相对路径（``.gitignore``）。
    ``keep``：``linkdir`` 专用的「不链」名单（工具自己往里写的产物目录）。
    """

    match: str
    kind: str
    keep: Tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if self.kind not in KINDS:
            raise ValueError(f"未知 kind：{self.kind}（可选 {', '.join(KINDS)}）")
        if not self.match:
            raise ValueError("rule.match 不能为空")


@dataclass(frozen=True)
class Target:
    """一个候选路径 + 它在文件系统里的三个事实（纯数据，便于测试）。"""

    path: str
    rule: Rule
    have_target: bool = False
    have_source: bool = False
    stale: bool = False


@dataclass(frozen=True)
class Action:
    """一条待执行（或待打印）的决定。"""

    path: str
    rule: Rule
    action: str

    @property
    def kind(self) -> str:
        return self.rule.kind


@dataclass
class Result:
    linked: int = 0
    skipped: int = 0
    installed: int = 0
    cleaned: int = 0
    warned: int = 0
    failed: int = 0

    @property
    def changed(self) -> bool:
        return bool(self.linked or self.installed or self.cleaned or self.failed)


# ---- Functional Core ------------------------------------------------------


def decide(
    kind: str,
    *,
    have_target: bool,
    have_source: bool,
    stale: bool = False,
) -> str:
    """四个布尔 → 一个动作。与 ``worktree-deps.sh`` 的 ``decide`` 逐条对齐。

    - 目标在：依赖落后就重装，否则跳过（目标在就够了，不覆盖）；
    - 目标不在、源在：链过来（``linkdir`` 是「建真目录 + 子项逐个链」）；
    - 目标不在、源也不在、是依赖：就地 ``npm ci``（新 clone 只能这样）；
    - 其余（私参文件缺失之类）：只 warn，绝不建空文件。
    """
    if have_target:
        if kind == NODE_MODULES and stale:
            return REINSTALL
        return SKIP
    if have_source:
        return LINK_ACTION
    if kind == NODE_MODULES:
        return INSTALL
    return WARN


def plan(targets: Iterable[Target]) -> Tuple[Action, ...]:
    """目标清单 → 动作清单（保持发现顺序，便于 dry-run 对账）。"""
    return tuple(
        Action(
            path=target.path,
            rule=target.rule,
            action=decide(
                target.rule.kind,
                have_target=target.have_target,
                have_source=target.have_source,
                stale=target.stale,
            ),
        )
        for target in targets
    )


def parse_rules(data: Dict[str, object], *, origin: str = "") -> List[Rule]:
    """toml 的 ``[[rule]]`` / ``disable`` → Rule 列表；坏条目跳过并 warn。"""
    rules: List[Rule] = []
    raw_rules = data.get("rule") or []
    if not isinstance(raw_rules, list):
        raw_rules = []
    for raw in raw_rules:
        if not isinstance(raw, dict):
            continue
        match = raw.get("match")
        kind = raw.get("kind")
        keep = raw.get("keep") or ()
        if not isinstance(match, str) or not isinstance(kind, str):
            print(f"  [warn] {origin}: 规则缺 match/kind，跳过", file=sys.stderr)
            continue
        if not isinstance(keep, (list, tuple)):
            keep = ()
        try:
            rules.append(Rule(match, kind, tuple(str(k) for k in keep)))
        except ValueError as exc:
            print(f"  [warn] {origin}: {exc}，跳过", file=sys.stderr)
    return rules


def disabled_patterns(data: Dict[str, object]) -> Tuple[str, ...]:
    raw = data.get("disable") or ()
    if not isinstance(raw, (list, tuple)):
        return ()
    return tuple(str(item) for item in raw)


def merge_rules(
    repo_rules: Sequence[Rule],
    global_rules: Sequence[Rule],
    builtin: Sequence[Rule],
    disabled: Sequence[str] = (),
) -> Tuple[Rule, ...]:
    """按优先级合并，并按 ``disable`` 里的 match 丢掉同名规则。"""
    merged: List[Rule] = []
    seen = set()
    for rule in (*repo_rules, *global_rules, *builtin):
        if rule.match in disabled:
            continue
        if rule.match in seen:
            continue
        seen.add(rule.match)
        merged.append(rule)
    return tuple(merged)


def format_action(action: Action, *, source_repo: str, worktree: str) -> Optional[str]:
    """一条动作的 dry-run 文案（与 ``worktree-deps.sh --dry-run`` 同口径）。

    返回 ``None`` 表示这条不该出声（``skip`` 默认静默：全部铺好的第二次调用应当零输出）。
    """
    src = os.path.join(source_repo, action.path)
    dst = os.path.join(worktree, action.path)
    if action.action == LINK_ACTION:
        label = "linkdir" if action.kind == LINKDIR else "link"
        return f"would {label}  {action.path} → {src}"
    if action.action == INSTALL:
        return f"would npm ci  {os.path.dirname(dst)}"
    if action.action == REINSTALL:
        return f"would npm ci  {os.path.dirname(dst)}（{action.path} 落后于清单）"
    if action.action == WARN:
        return f"warn        {action.path} 在 {worktree} 和主 checkout 里都没有（本机私参？跳过）"
    return None


# ---- Imperative Shell：读规则 --------------------------------------------------
GLOBAL_CONFIG_ENV = "WORKTREE_HOOKS_CONFIG"
REPO_CONFIG_RELPATH = os.path.join(".pi", "worktree-hooks.toml")

BUILTIN_RULES: Tuple[Rule, ...] = (
    Rule("**/node_modules", NODE_MODULES),
    Rule("**/.nsh", LINKDIR, ("test", "test-logs")),
    Rule("**/env.local", LINK),
    # 嵌套的 ``.pi``（如 ``tools/.pi``）也是只活在本机的状态：建真目录 + 子项逐个链。
    # **根** ``.pi`` 是混合目录（tracked 跟着分支走），走 defaults 的逐条目镜像，
    # 这里在 :func:`discover` 里显式跳过 —— 绝不把根 ``.pi`` 整层链到主 checkout。
    Rule("**/.pi", LINKDIR),
    Rule(".gitignore", LINK),
)

# 根 ``.pi`` 由 :mod:`worktree_hooks.defaults` 的 ``mirror_pi_untracked`` 负责（它要
# 区分 tracked / untracked），规则层不碰它。
ROOT_PI_MIRRORED_BY_DEFAULTS = ".pi"


def global_config_path() -> str:
    override = os.environ.get(GLOBAL_CONFIG_ENV)
    if override:
        return os.path.abspath(override)
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
        os.path.expanduser("~"), ".config",
    )
    return os.path.join(base, "worktree-hooks", "config.toml")


def _read_toml(path: str) -> Dict[str, object]:
    """读一个 toml；缺文件返回 {}，解析失败 warn 后返回 {}（规则表不该让 presetup 死）。"""
    if not os.path.isfile(path):
        return {}
    try:
        import tomllib  # Python ≥ 3.11
    except ImportError:  # pragma: no cover - 3.10 及更老的解释器
        print(
            f"  [warn] {path}: 这个 Python 没有 tomllib（< 3.11），跳过声明式规则",
            file=sys.stderr,
        )
        return {}
    try:
        with open(path, "rb") as fh:
            data = tomllib.load(fh)
    except (OSError, ValueError) as exc:
        print(f"  [warn] {path}: 读不了（{exc}），跳过", file=sys.stderr)
        return {}
    return data if isinstance(data, dict) else {}


def load_rules(source_repo: str) -> Tuple[Rule, ...]:
    """仓库级 → 全局 → 内置，三层合成一张表（``disable`` 可裁掉内置项）。"""
    repo_path = os.path.join(source_repo, REPO_CONFIG_RELPATH)
    glob_path = global_config_path()
    repo_data = _read_toml(repo_path)
    glob_data = _read_toml(glob_path)
    return merge_rules(
        parse_rules(repo_data, origin=repo_path),
        parse_rules(glob_data, origin=glob_path),
        BUILTIN_RULES,
        disabled=disabled_patterns(repo_data) + disabled_patterns(glob_data),
    )


# ---- Imperative Shell：找候选 --------------------------------------------------


def _glob_name(match: str) -> Optional[str]:
    """``**/x`` / ``**\\x`` → ``x``；字面路径 → ``None``。"""
    prefix = "**/"
    return match[len(prefix):] if match.startswith(prefix) else None


def _walk_by_name(root: str, name: str) -> List[str]:
    """在 *root* 下找所有恰好叫 *name* 的条目（相对路径，由浅到深）。

    - 不跟随 symlink：worktree 之间共享链接是常事，跟进去会跑出这棵树；
    - 命中之后不再下钻（``node_modules`` 里嵌套的 ``node_modules`` 不是我们要补的）；
    - ``.git`` 一律跳过：worktree 的 ``.git`` 是指向 ``<common>/worktrees/…`` 的文件或链。
    """
    found: List[str] = []
    root = os.path.abspath(root)
    for current, dirnames, filenames in os.walk(root, followlinks=False):
        rel_dir = os.path.relpath(current, root)
        depth = 0 if rel_dir == "." else rel_dir.count(os.sep) + 1
        if depth >= MAX_DEPTH:
            dirnames[:] = []
            continue
        names = list(dirnames) + list(filenames)
        keep_dirs: List[str] = []
        for entry in sorted(names):
            if entry in WALK_SKIP:
                continue
            rel = entry if rel_dir == "." else os.path.join(rel_dir, entry)
            if entry == name:
                found.append(rel)
                continue
            if entry in dirnames and not os.path.islink(os.path.join(current, entry)):
                keep_dirs.append(entry)
        dirnames[:] = [d for d in dirnames if d in keep_dirs]
    return found


def discover(source_repo: str, rules: Sequence[Rule]) -> List[Tuple[str, Rule]]:
    """按规则表在**源仓库**里找候选（工作目录只补源里有的东西）。

    只扫源仓库、不扫 worktree：需要铺什么由源决定，worktree 里的现状在
    :func:`inspect` 里读。字面路径规则直接查存在性，不遍历。
    """
    source_repo = os.path.abspath(source_repo)
    found: List[Tuple[str, Rule]] = []
    claimed: Dict[str, Rule] = {}
    for rule in rules:  # 先命中先得：仓库级规则优先于内置
        name = _glob_name(rule.match)
        if name is None:
            if os.path.lexists(os.path.join(source_repo, rule.match)):
                claimed.setdefault(rule.match, rule)
            continue
        for rel in _walk_by_name(source_repo, name):
            if name == ROOT_PI_MIRRORED_BY_DEFAULTS and rel == name:
                # 根 ``.pi`` 交给 defaults 的逐条目镜像：整层连接会把 tracked 内容也
                # 串到主 checkout 的分支上。
                continue
            claimed.setdefault(rel, rule)
    for path, rule in claimed.items():
        found.append((path, rule))
    return found


def _is_stale_deps(node_modules: str) -> bool:
    """依赖是否落后于清单（只看 mtime，不跑 npm —— 这在每次 make 的路径上）。

    安装标记 ``node_modules/.package-lock.json`` 是 npm 自己写的；缺了就不判落后
    （手搓 / fixture 目录猜错了会变成每次重装）。
    """
    marker = os.path.join(node_modules, ".package-lock.json")
    if not os.path.isfile(marker):
        return False
    try:
        marker_mtime = os.path.getmtime(marker)
    except OSError:
        return False
    parent = os.path.dirname(node_modules)
    for name in ("package.json", "package-lock.json"):
        manifest = os.path.join(parent, name)
        try:
            if os.path.getmtime(manifest) > marker_mtime:
                return True
        except OSError:
            continue
    return False


def inspect(
    source_repo: str,
    worktree: str,
    pairs: Sequence[Tuple[str, Rule]],
) -> List[Target]:
    """补上文件系统事实（目标在不在、源在不在、依赖落没落后）。"""
    source_repo = os.path.abspath(source_repo)
    worktree = os.path.abspath(worktree)
    targets: List[Target] = []
    for path, rule in pairs:
        src = os.path.join(source_repo, path)
        dst = os.path.join(worktree, path)
        have_target = os.path.lexists(dst)
        if rule.kind == LINKDIR and os.path.islink(dst):
            # 旧形态「整目录 symlink」正是要换掉的：按「没有」处理，重建真目录。
            have_target = False
        have_source = src != dst and os.path.lexists(src)
        stale = False
        if rule.kind == NODE_MODULES and have_target:
            stale = _is_stale_deps(os.path.realpath(dst))
        targets.append(
            Target(
                path=path,
                rule=rule,
                have_target=have_target,
                have_source=have_source,
                stale=stale,
            )
        )
    return targets


def build_plan(source_repo: str, worktree: str) -> Tuple[Action, ...]:
    """:func:`load_rules` → :func:`discover` → :func:`inspect` → :func:`plan`。"""
    rules = load_rules(source_repo)
    return plan(inspect(source_repo, worktree, discover(source_repo, rules)))


# ---- Imperative Shell：动磁盘 --------------------------------------------------


def _link_children(src: str, dst: str, keep: Sequence[str]) -> None:
    """``linkdir``：目录本身是真目录，子项逐个链（nsh 顺着 realpath 认 app 根）。"""
    os.makedirs(dst, exist_ok=True)
    for entry in os.listdir(src):
        if entry in keep:
            continue
        os.symlink(os.path.join(src, entry), os.path.join(dst, entry))


def _run_npm_ci(directory: str) -> bool:
    if not os.path.isfile(os.path.join(directory, "package.json")):
        print(f"  [warn] {directory} 没有 package.json，跳过", file=sys.stderr)
        return True
    try:
        proc = subprocess.run(
            ["npm", "ci"], cwd=directory, capture_output=True, text=True,
            check=False, timeout=600,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"  [warn] npm ci 跑不起来：{exc}", file=sys.stderr)
        return False
    if proc.returncode != 0:
        print(f"  [warn] npm ci 失败：{directory}", file=sys.stderr)
        return False
    return True


def apply(
    source_repo: str,
    worktree: str,
    actions: Sequence[Action],
    *,
    dry_run: bool = False,
    verbose: bool = False,
) -> Result:
    """执行 :func:`plan` 的结果。幂等：全部铺好时零动作、零输出。"""
    source_repo = os.path.abspath(source_repo)
    worktree = os.path.abspath(worktree)
    result = Result()

    for action in actions:
        src = os.path.join(source_repo, action.path)
        dst = os.path.join(worktree, action.path)

        if action.action == SKIP:
            result.skipped += 1
            # 老 worktree 里 linkdir 的 keep 项可能还是整项 symlink：那是老症状
            # （nsh 顺着 realpath 跑回主 checkout），清掉让工具自己写真的。
            if action.kind == LINKDIR:
                for name in action.rule.keep:
                    stale_link = os.path.join(dst, name)
                    if not os.path.islink(stale_link):
                        continue
                    if dry_run:
                        print(f"would unlink  {action.path}/{name}（产物目录要留在 worktree）")
                    else:
                        os.unlink(stale_link)
                        print(f"  [ok] unlinked {action.path}/{name}（产物目录要留在 worktree）")
                        result.cleaned += 1
            elif verbose:
                print(f"  [skip] {action.path} 已存在", file=sys.stderr)
            continue

        if action.action == WARN:
            result.warned += 1
            print(
                f"  [warn] {action.path} 在主 checkout 里也没有（本机私参？跳过）",
                file=sys.stderr,
            )
            continue

        if action.action in (INSTALL, REINSTALL):
            # 目标可能是 symlink：绝不在 link 里跑 npm ci（npm 会把自己那个 link 删掉
            # 换成真目录，一份依赖共享给所有 worktree 的前提就没了），要 cd 进真目录。
            directory = (
                os.path.dirname(os.path.realpath(dst))
                if action.action == REINSTALL
                else os.path.dirname(dst)
            )
            if dry_run:
                detail = "（落后于清单）" if action.action == REINSTALL else ""
                print(f"would npm ci  {directory}{detail}")
                continue
            if _run_npm_ci(directory):
                print(f"  [ok] npm ci {directory}", file=sys.stderr)
                result.installed += 1
            else:
                result.failed += 1
            continue

        if dry_run:
            print(format_action(action, source_repo=source_repo, worktree=worktree) or "")
            continue

        try:
            if action.kind == LINKDIR:
                if os.path.islink(dst):
                    os.unlink(dst)
                _link_children(src, dst, action.rule.keep)
                print(f"  [ok] linkdir {action.path} → {src}（子项逐个链）", file=sys.stderr)
            else:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                os.symlink(src, dst, target_is_directory=os.path.isdir(src))
                print(f"  [ok] linked {action.path} → {src}", file=sys.stderr)
            result.linked += 1
        except OSError as exc:
            print(f"  [warn] {action.path}: {exc}", file=sys.stderr)
            result.failed += 1

    return result


def clean(
    source_repo: str,
    worktree: str,
    *,
    dry_run: bool = False,
    verbose: bool = False,
) -> Result:
    """回收 presetup 建出来的链接（只删指向源同名条目的链，tracked 内容一律不动）。"""
    source_repo = os.path.abspath(source_repo)
    worktree = os.path.abspath(worktree)
    result = Result()
    rules = load_rules(source_repo)

    for path, rule in discover(source_repo, rules):
        src = os.path.join(source_repo, path)
        dst = os.path.join(worktree, path)
        if rule.kind == LINKDIR and os.path.isdir(dst) and not os.path.islink(dst):
            for entry in os.listdir(dst):
                child = os.path.join(dst, entry)
                if not os.path.islink(child):
                    continue
                if os.path.realpath(child) != os.path.realpath(os.path.join(src, entry)):
                    continue
                if dry_run:
                    print(f"would unlink  {path}/{entry}")
                else:
                    os.unlink(child)
                    print(f"  [ok] unlinked {path}/{entry}", file=sys.stderr)
                    result.cleaned += 1
            continue
        if not os.path.islink(dst):
            if verbose:
                print(f"  [skip] {path} 不是链接", file=sys.stderr)
            continue
        try:
            actual = os.path.realpath(dst)
        except OSError:
            continue
        if actual != os.path.realpath(src):
            continue
        if dry_run:
            print(f"would unlink  {path}")
        else:
            os.unlink(dst)
            print(f"  [ok] unlinked {path}", file=sys.stderr)
            result.cleaned += 1
    return result
