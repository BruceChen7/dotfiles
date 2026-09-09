#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
picker.py — herdr-pi-session-resume 薄 shell。

Subcommands（见 herdr-plugin.toml）:
    picker     — 主 fzf picker 循环（prefix+p）
    preview    — fzf preview 渲染器（读取选中行的 TSV 字段）
    open       — 打开 picker popup pane
    agentstart — 后台子命令：resume 的 `herdr agent start`（popup 已关闭，
                 成功静默；agent_pane_busy 竞态自动重试；失败用 herdr
                 notification 提示，终端零输出）

职责边界：session_index.py 是纯函数核心；本文件只做 IO / 编排——
扫描 session 目录、增量缓存读写、fzf 交互、herdr CLI（split + agent start）、
剪贴板。所有决策逻辑都委托给 session_index.py。
"""

import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import NoReturn

sys.path.insert(0, str(Path(__file__).resolve().parent))

import session_index as idx

_HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
SESSIONS_ROOT = Path(
    os.environ.get("PI_SESSIONS_ROOT", str(Path.home() / ".pi" / "agent" / "sessions"))
)
CACHE_FILE_NAME = "session-index.json"
AGENT_START_TIMEOUT = 35  # 略大于 herdr 默认 30s，留缓冲
AGENT_START_RETRY_WINDOW = 15  # agent_pane_busy（新 pane shell 初始化竞态）最长重试秒数
AGENT_START_RETRY_SLEEP = 0.5  # 每次 busy 重试的间隔秒数
FZF_EXPECT_KEYS = {"alt-enter", "ctrl-y"}

COLOR_RED = "\033[31m"
COLOR_YELLOW = "\033[33m"
COLOR_GRAY = "\033[90m"
COLOR_BOLD = "\033[1m"
RESET = "\033[0m"


# ---- shell: session 扫描 + 增量缓存 -------------------------------------------


def scan_session_files(root: Path) -> list[Path]:
    """收集全部待索引的 .jsonl（跳过临时/私有目录）。"""
    if not root.is_dir():
        return []
    files: list[Path] = []
    for entry in sorted(root.iterdir()):
        if not entry.is_dir() or not idx.classify_session_dir(entry.name):
            continue
        files.extend(sorted(entry.glob("*.jsonl")))
    return files


def _state_dir() -> Path:
    """插件 state 目录。

    herdr 在 macOS/Linux 的真实路径是 `~/.local/state/herdr/plugins/<id>`
    （config::state_dir() = $HOME/.local/state/herdr），而非 ~/.config/...。
    运行时 HERDR_PLUGIN_STATE_DIR 由 herdr 注入；fallback 必须对齐真实路径，
    否则本地验证与 herdr 实际读写的缓存是两份（2026-09-04 踩坑：
    验证重建 ~/.config 下的缓存，用户却一直读 ~/.local/state 下的旧缓存）。
    """
    explicit = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if explicit:
        return Path(explicit)
    return (
        Path.home()
        / ".local"
        / "state"
        / "herdr"
        / "plugins"
        / "herdr-pi-session-resume"
    )


def _cache_file() -> Path:
    return _state_dir() / CACHE_FILE_NAME


def load_cache() -> dict:
    """读缓存；逻辑版本不匹配 → 返回 {}（触发全量重建）。"""
    try:
        raw = json.loads(_cache_file().read_text())
        if not isinstance(raw, dict):
            return {}
        if raw.get("version") != idx.INDEX_LOGIC_VERSION:
            return {}
        return raw.get("entries", {})
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(cache: dict) -> None:
    """写缓存，带逻辑版本号（version 变化时 load_cache 会全量重建）。"""
    _state_dir().mkdir(parents=True, exist_ok=True)
    payload = {"version": idx.INDEX_LOGIC_VERSION, "entries": cache}
    fd, tmp = tempfile.mkstemp(dir=str(_state_dir()), prefix=CACHE_FILE_NAME + ".tmp.")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, str(_cache_file()))
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read_file_truncated(path: Path, max_bytes: int) -> str:
    """读取文件前 max_bytes 字节（超限截断，防止超大文件拖慢）。"""
    with open(path, "rb") as f:
        data = f.read(max_bytes)
    return data.decode("utf-8", errors="replace")


def build_indexes() -> list[idx.SessionIndex]:
    """扫描 + 增量解析：返回全部 SessionIndex（已含缓存命中）。"""
    cache = load_cache()
    files = scan_session_files(SESSIONS_ROOT)
    fresh: list[idx.SessionIndex] = []
    kept = {}
    for path in files:
        try:
            st = path.stat()
        except OSError:
            continue
        mtime, size = st.st_mtime, st.st_size
        cached = cache.get(str(path))
        if not idx.needs_reparse(mtime, size, cached):
            kept[str(path)] = cached
            continue
        text = _read_file_truncated(path, idx.MAX_FILE_BYTES)
        parsed = idx.build_index_from_lines(
            text.splitlines(), path=str(path), mtime=mtime, size=size
        )
        if parsed is None:
            continue  # 空文件 / 无消息 → 不入索引
        fresh.append(parsed)
        kept[str(path)] = {"mtime": mtime, "size": size, "index": parsed.to_dict()}
    if fresh:
        save_cache(idx.cache_merge(kept, fresh))
    return [idx.SessionIndex.from_dict(v["index"]) for v in kept.values()]


# ---- shell: fzf -------------------------------------------------------------


def _fzf_base_args() -> list[str]:
    return [
        "fzf",
        "--ansi",
        "--layout=default",  # 从底部显示：第 1 行（最新 session）贴近输入框，向上按时间递减
        "--sync",
        "--delimiter",
        "\t",
        "--with-nth=1",  # 只显示 display 列；搜索/预览仍用原始整行
        "--exact",  # 连续子串匹配（替代 fuzzy 子序列），大幅降噪；全文仍在第 1 列可搜
        "--no-hscroll",  # 禁用横向滚动：display 列含全文(4000+字符)，匹配深处时不滚动挤掉行首结构
        "--no-multi",
        "--no-sort",
        "--tiebreak=index",
    ]


def run_fzf(
    lines: str, query: str, binds: str, header: str, preview_cmd: str
) -> tuple[int, str]:
    args = _fzf_base_args() + [
        "--header",
        header,
        "--preview",
        preview_cmd,
        "--preview-window=right:45%",
        "--bind",
        binds,
        "--print-query",
        "--expect=alt-enter,ctrl-y",
        "--query",
        query,
    ]
    try:
        p = subprocess.run(
            args, input=lines, capture_output=True, text=True, timeout=300, check=False
        )
        return p.returncode, p.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def parse_fzf_output(out: str) -> tuple[str, str, str]:
    """fzf --print-query --expect 输出：query / 按键（''=enter）/ 选中行。"""
    # Do not use str.splitlines(): our TSV content field encodes message
    # newlines as idx.CONTENT_NL (\x1e), and splitlines() treats \x1e as a
    # line boundary. That truncates the selected row before the raw_cwd field,
    # causing resume to fall back to the redacted ~/... cwd and split the
    # current space without --cwd.
    lines = out.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    query = lines[0] if len(lines) > 0 else ""
    if len(lines) >= 3 and (lines[1] == "" or lines[1] in FZF_EXPECT_KEYS):
        return query, lines[1], lines[2]
    # fzf --filter prints query + selected row without an empty key line. The
    # interactive picker normally emits the blank key line for Enter, but this
    # fallback keeps the parser correct for non-interactive harnesses too.
    if len(lines) >= 2:
        return query, "", lines[1]
    return query, "", ""


# ---- shell: 终端 -------------------------------------------------------------


def _read_key() -> str:
    import termios
    import tty

    try:
        fd = sys.stdin.fileno()
        if not os.isatty(fd):
            return ""
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            return sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
    except Exception:  # noqa: BLE001 - 兜底：非 tty / termios 失败时当无按键处理
        return ""


def fail(msg: str) -> NoReturn:
    print(f"{COLOR_RED}{msg}{RESET}", file=sys.stderr)
    print(f"{COLOR_GRAY}按任意键关闭…{RESET}", file=sys.stderr, end="")
    _read_key()
    sys.exit(1)


def warn(msg: str) -> None:
    print(f"{COLOR_RED}{msg}{RESET}", file=sys.stderr)
    print(f"{COLOR_GRAY}按任意键继续…{RESET}", file=sys.stderr, end="")
    _read_key()
    print("\n", file=sys.stderr)


def herdr(*args: str, timeout: int = AGENT_START_TIMEOUT) -> dict | None:
    """Run herdr CLI; parsed JSON on success, None on failure/timeout."""
    try:
        p = subprocess.run(
            [_HERDR, *args],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if p.returncode != 0:
        return None
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return None


# ---- shell: 剪贴板 ------------------------------------------------------------


def copy_to_clipboard(text: str) -> bool:
    if shutil.which("pbcopy"):
        try:
            subprocess.run(["pbcopy"], input=text, text=True, check=True, timeout=10)
            return True
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            return False
    for tool in ("xclip", "wl-copy"):
        if shutil.which(tool):
            args = [tool]
            if tool == "xclip":
                args += ["-selection", "clipboard"]
            try:
                subprocess.run(args, input=text, text=True, check=True, timeout=10)
                return True
            except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
                continue
    return False


# ---- shell: 动作 --------------------------------------------------------------


def _start_agent_async(session_path: str, pane_id: str) -> bool:
    """异步启动 pi：popup 立即关闭，agent start 交给后台独立进程。

    背景：`herdr agent start` 会阻塞到 pi 就绪（默认 30s，herdr skill doc），
    同步实现让 popup 全程停在焦点上并打印状态日志。改为 spawn 一个
    detached 子进程跑 `picker.py agentstart`——目标 pane 自然展示 pi 启动
    过程；失败由子进程用 herdr notification 提示（正常路径零日志）。

    True → popup 关闭（子进程脱离 popup 进程组，pane 关闭不影响后台）。
    """
    log = _state_dir() / "agent-start.log"
    _state_dir().mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        str(Path(__file__).resolve()),
        "agentstart",
        pane_id,
        session_path,
    ]
    try:
        with open(log, "a") as lf:
            subprocess.Popen(
                cmd,
                stdin=subprocess.DEVNULL,
                stdout=lf,
                stderr=subprocess.STDOUT,
                start_new_session=True,  # setsid：脱离 popup 进程组
            )
        return True
    except OSError:
        return False


def _split_pane(cwd: str) -> str | None:
    """现状降级路径：当前 space split 新 pane（cwd=session 原 cwd）→ pane_id。

    关键坑（herdr 源码实证）：插件 popup 进程**没有** HERDR_PANE_ID env
    （plugin_pane_launch_env 只注入 HERDR_PLUGIN_CONTEXT_JSON），所以
    `pane split --current` 会报 "--current requires HERDR_PANE_ID"。
    目标 pane 必须从 HERDR_PLUGIN_CONTEXT_JSON.focused_pane_id 取——
    它是用户打开 popup 前聚焦的 pane（split 的目标）。
    """
    target_pane = idx.parse_context_pane_id(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON"))
    if not target_pane:
        warn(
            "无法确定 split 目标 pane（HERDR_PLUGIN_CONTEXT_JSON 缺少 focused_pane_id）"
        )
        return None

    split_args = ["pane", "split", target_pane, "--direction", "right", "--no-focus"]
    # session 原 cwd 可能已被删除——目录不存在时不传 --cwd（让新 pane 继承当前 cwd）
    if cwd and os.path.isdir(cwd):
        split_args += ["--cwd", cwd]
    data = herdr(*split_args, timeout=15)
    if data is None:
        warn(f"pane split 失败: {target_pane}（当前 pane 不可分割？）")
        return None
    pane_id = data.get("result", {}).get("pane", {}).get("pane_id")
    if not pane_id:
        warn("pane split 未返回 pane_id")
        return None
    return pane_id


def _tab_in_workspace(workspace_id: str, cwd: str) -> tuple[str | None, str]:
    """跳转 space + 开新 tab，返回 (root pane_id, 失败原因)。

    成功时（root_pane_id, ""）；失败时（None, 原因）供调用方降级/提示。
    """
    if herdr("workspace", "focus", workspace_id) is None:
        return None, f"workspace focus 失败: {workspace_id}"
    create_args = ["tab", "create", "--workspace", workspace_id]
    # session 原 cwd 可能已被删除——目录不存在时不传 --cwd
    if cwd and os.path.isdir(cwd):
        create_args += ["--cwd", cwd]
    create_args += ["--focus"]
    data = herdr(*create_args, timeout=15)
    if data is None:
        return None, f"tab create 失败: workspace {workspace_id}"
    pane_id = data.get("result", {}).get("root_pane", {}).get("pane_id")
    if not pane_id:
        return None, "tab create 未返回 root_pane.pane_id"
    return pane_id, ""


def _new_workspace_for_cwd(cwd: str) -> tuple[str | None, str]:
    """session cwd 无已开 workspace 时：新建带 cwd 的 workspace → root_pane_id。

    `workspace create --cwd <path> --focus` 一次调用即建好 workspace + 首个
    tab + root pane（shell 起始 cwd = session 原 cwd，实测返回
    result.root_pane.pane_id），无需再 tab create；--focus 让用户落在新
    space（pi 随后在此 root pane 启动），与 _tab_in_workspace 的跳转行为一致。

    成功 → (root_pane_id, "")；失败 → (None, 原因) 供调用方降级。
    """
    create_args = ["workspace", "create"]
    # session 原 cwd 可能已被删除——目录不存在时不传 --cwd（继承当前 cwd）
    if cwd and os.path.isdir(cwd):
        create_args += ["--cwd", cwd]
    create_args += ["--focus"]
    data = herdr(*create_args, timeout=15)
    if data is None:
        return None, "workspace create 失败"
    pane_id = data.get("result", {}).get("root_pane", {}).get("pane_id")
    if not pane_id:
        return None, "workspace create 未返回 root_pane.pane_id"
    return pane_id, ""


def do_resume(session_path: str, cwd: str) -> bool:
    """enter → 目标 pane 选择（2026-09-07 起优先级）：

      1. session 原 cwd 已有专属 space → 跳转并开新 tab（_tab_in_workspace）；
      2. 无匹配 space 且 cwd 有效 → 新建带 cwd 的 workspace
         （_new_workspace_for_cwd：1 次调用，root pane 即目标）；
      3. 上述失败 / cwd 缺失 / pane list 查询失败 → 维持现状：当前 space
         split 新 pane（_split_pane）。

    选定 pane 后统一 _start_agent_async（popup 立即关闭，后台启动 pi）。

    True → popup 应关闭。

    space 判定（2026-09-04 用户决策）：workspace 本身不暴露 cwd，靠
    pane list 的 cwd + workspace_id 匹配；匹配优先 focused workspace。
    """
    pane_id = None
    panes_json = herdr("pane", "list", timeout=15)
    if panes_json is not None:
        panes = panes_json.get("result", {}).get("panes", []) or []
        wid = idx.find_workspace_for_cwd(panes, cwd)
        if wid:
            pane_id, reason = _tab_in_workspace(wid, cwd)
            if pane_id is None:
                warn(f"{reason}，降级为当前 space split 新 pane")
        elif cwd and os.path.isdir(cwd):
            # 无匹配 space 且 cwd 有效 → 新建带 cwd 的 workspace（2026-09-07
            # 用户决策：比在当前 space 塞一个无关 pane 更干净）
            pane_id, reason = _new_workspace_for_cwd(cwd)
            if pane_id is None:
                warn(f"{reason}，降级为当前 space split 新 pane")
    if pane_id is None:
        pane_id = _split_pane(cwd)
        if pane_id is None:
            return False
    return _start_agent_async(session_path, pane_id)


def do_fork(session_path: str) -> bool:
    """alt+enter → 复制 `pi --fork <path>` 命令 + 提示手动执行（v1 取舍）。

    True → popup 应关闭。
    """
    cmd = f"pi --fork {shlex.quote(session_path)}"
    if copy_to_clipboard(cmd):
        print(
            f"{COLOR_YELLOW}已复制: {cmd}{RESET}\n"
            f"{COLOR_GRAY}agent start 传 fork 参数交互复杂，v1 先复制命令，"
            f"请粘贴到目标 pane 手动执行。按任意键关闭…{RESET}",
            file=sys.stderr,
        )
    else:
        print(
            f"{COLOR_YELLOW}无法复制到剪贴板。请手动执行: {cmd}{RESET}\n"
            f"{COLOR_GRAY}按任意键关闭…{RESET}",
            file=sys.stderr,
        )
    _read_key()
    return True


def do_copy(session_path: str) -> bool:
    """ctrl+y → 复制 `pi --session <path>` 命令。True → popup 应关闭。"""
    cmd = f"pi --session {shlex.quote(session_path)}"
    if copy_to_clipboard(cmd):
        print(f"{COLOR_GRAY}已复制: {cmd}{RESET}", file=sys.stderr)
    else:
        print(
            f"{COLOR_YELLOW}无法复制到剪贴板。请手动执行: {cmd}{RESET}\n"
            f"{COLOR_GRAY}按任意键关闭…{RESET}",
            file=sys.stderr,
            end="",
        )
        _read_key()
    return True


def _pane_has_agent(pane_id: str) -> bool:
    """agent list 是否已有 agent 占用该 pane（agent start 报错但 pi 实际起来了）。"""
    data = herdr("agent", "list", timeout=15)
    if not data:
        return False
    agents = data.get("result", {}).get("agents", []) or []
    return any(isinstance(a, dict) and str(a.get("pane_id")) == pane_id for a in agents)


def _run_agent_start(name: str, pane_id: str, session_path: str) -> tuple[bool, str]:
    """单次 `herdr agent start`：成功 → (True, "")；失败 → (False, 错误文本)。

    herdr CLI 对 API 错误（含 agent_pane_busy）退出码非 0，错误 JSON 在
    stdout/stderr——两者拼接返回给调用方判断可重试性。
    """
    try:
        p = subprocess.run(
            [
                _HERDR,
                "agent",
                "start",
                name,
                "--kind",
                "pi",
                "--pane",
                pane_id,
                "--",
                "--session",
                session_path,
            ],
            capture_output=True,
            text=True,
            timeout=AGENT_START_TIMEOUT,
            check=False,
        )
        if p.returncode == 0:
            return True, ""
        return False, (p.stderr or "") + (p.stdout or "")
    except (OSError, subprocess.TimeoutExpired):
        return False, "agent start 子进程超时或无法运行"


def sub_agentstart() -> None:
    """后台子命令：resume 的 `herdr agent start`（popup 已关闭，无终端交互）。

    成功 → 静默退出（pi 已在目标 pane 启动，用户直接看到）。

    agent_pane_busy → 以 AGENT_START_RETRY_SLEEP 间隔重试至多
    AGENT_START_RETRY_WINDOW 秒。背景（2026-09-07 实证）：新 split 的 pane
    前 ~1s 在「zsh 独占 / zsh+启动子进程(env·mise·starship·atuin·git) /
    独立进程组守护进程」之间切换；herdr 的 agent start CLI 只在 shell
    初始化态的 2s 内重试，且一旦某个探测命中 pgid≠shell 的瞬态（如守护
    进程）就提前放弃返回 agent_pane_busy——异步 resume 恰好把 agent start
    落在竞态窗口内，必须由这层兜底重试。

    agent_not_ready → pi 已在启动中，静默等它（不重试，避免重复发送 pi）。
    pane 已注册 agent（_pane_has_agent）→ 说明 pi 实际已起来，静默成功。
    其余错误 / 窗口耗尽 → herdr notification 提示（代替 popup 里的
    warn / 日志），并记一行到 state 目录 agent-start.log（隐藏文件）。
    """
    pane_id = sys.argv[2] if len(sys.argv) > 2 else ""
    session_path = sys.argv[3] if len(sys.argv) > 3 else ""
    name = f"resume-{int(time.time())}-{os.getpid()}"
    deadline = time.monotonic() + AGENT_START_RETRY_WINDOW
    err = ""
    while True:
        if _pane_has_agent(pane_id):
            return  # pi 实际已在 pane 上（busy 误报场景），静默成功
        ok, err = _run_agent_start(name, pane_id, session_path)
        if ok:
            return
        if "agent_not_ready" in err:
            return  # pi 启动中，不打扰
        if "agent_pane_busy" not in err or time.monotonic() >= deadline:
            break
        time.sleep(AGENT_START_RETRY_SLEEP)
    body = (
        f"pane {pane_id} 启动 pi 失败：{err.strip()[:300] or '未知错误'}\n"
        f"可手动运行：pi --session {session_path}"
    )
    herdr("notification", "show", "pi session resume 失败", "--body", body)
    try:
        with open(_state_dir() / "agent-start.log", "a") as lf:
            lf.write(
                f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] resume failed "
                f"pane={pane_id} session={session_path}\n{err}\n"
            )
    except OSError:
        pass


# ---- 子命令 ------------------------------------------------------------------


def sub_picker() -> None:
    here = Path(__file__).resolve().parent
    preview_cmd = f"uv run {shlex.quote(str(here / 'picker.py'))} preview {{}}"
    scope_cmd = f"uv run {shlex.quote(str(here / 'picker.py'))}"
    query = ""
    home = str(Path.home())

    while True:
        indexes = build_indexes()
        if not indexes:
            fail("未找到任何 pi session（~/.pi/agent/sessions/）")
        groups = idx.group_by_cwd(indexes)
        lines = idx.build_lines(groups, home)
        # ctrl-g: 二次筛选（仿 snacks.nvim grep picker 的 <c-g>=tcd+picker_grep）——
        #   reload 用 scope 子命令的 stdout 动态替换输入列表（fzf 不重启、query 保留），
        #   列表收窄到当前选中 session 的项目目录后可继续输入筛选。
        #   {8} = 当前行第 8 列（raw_cwd，--delimiter 已设为 \t）；组头/空 cwd → 全量。
        # alt-g: 恢复全部项目。
        binds = (
            "alt-enter:accept,ctrl-y:accept,start:pos(2),load:pos(2),"
            f"ctrl-g:reload({scope_cmd} scope {{8}}),"
            f"alt-g:reload({scope_cmd} scope)"
        )
        header = (
            f"共 {len(indexes)} 个 session · {len(groups)} 个项目    "
            "enter=resume · alt+enter=fork · ctrl+y=复制 · ctrl-g=项目内筛选 · alt-g=全部 · esc=退出"
        )
        rc, out = run_fzf(
            lines, query, binds=binds, header=header, preview_cmd=preview_cmd
        )
        if rc != 0:
            sys.exit(0)  # 取消 / fzf 缺失 → 静默退出

        query, key, line = parse_fzf_output(out)
        if not line:
            continue
        fields = line.split("\t")
        session_path = fields[1] if len(fields) > 1 else ""
        if not session_path:
            continue  # 选中组头行 → 无动作，留在列表
        # 用 raw_cwd 列（index 7）：redact 后的 `~/x` 无法被 os.path.isdir 解析
        cwd = fields[7] if len(fields) > 7 else fields[2]
        target = Path(session_path)

        if key == "ctrl-y":
            if do_copy(str(target)):
                break
            continue
        if key == "alt-enter":
            if do_fork(str(target)):
                break
            continue
        # enter → resume
        if do_resume(str(target), cwd):
            break


def sub_scope() -> None:
    """ctrl-g 二次筛选：输出仅包含指定 cwd 项目的 fzf 行。

    由 fzf become 调用：become 用本命令的 stdout 替换 fzf 输入并重启
    （query 保留），等价于 snacks.nvim grep picker 的 <c-g>（tcd 到当前项
    所在目录后重新筛选）。参数为空 → 输出全量（alt-g 恢复全部）。
    """
    cwd = sys.argv[2] if len(sys.argv) > 2 else ""
    home = str(Path.home())
    indexes = build_indexes()
    groups = idx.scope_groups(idx.group_by_cwd(indexes), cwd)
    sys.stdout.write(idx.build_lines(groups, home))


def sub_preview() -> None:
    line = sys.argv[2] if len(sys.argv) > 2 else ""
    sys.stdout.write(idx.preview_text(line))


def sub_open() -> None:
    herdr_bin = os.environ.get("HERDR_BIN_PATH", "herdr")
    plugin_id = os.environ.get("HERDR_PLUGIN_ID", "herdr-pi-session-resume")
    os.execvp(
        herdr_bin,
        [
            herdr_bin,
            "plugin",
            "pane",
            "open",
            "--plugin",
            plugin_id,
            "--entrypoint",
            "picker",
        ],
    )


SUBCOMMANDS = {
    "picker": sub_picker,
    "preview": sub_preview,
    "open": sub_open,
    "scope": sub_scope,
    "agentstart": sub_agentstart,
}


# ---- entry point -------------------------------------------------------------


def main() -> None:
    # 管道被下游提前关闭（如 `| head`）时静默退出，不打印 BrokenPipeError 栈
    import signal

    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sub = sys.argv[1] if len(sys.argv) > 1 else ""
    handler = SUBCOMMANDS.get(sub)
    if handler is None:
        print(f"usage: picker.py <{'|'.join(SUBCOMMANDS)}>", file=sys.stderr)
        sys.exit(2)
    try:
        handler()
    except Exception:  # noqa: BLE001 - 兜底：任何异常打印栈后退出
        import traceback

        traceback.print_exc(file=sys.stderr)


if __name__ == "__main__":
    main()
