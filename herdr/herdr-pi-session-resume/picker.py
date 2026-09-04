#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
picker.py — herdr-pi-session-resume 薄 shell。

Subcommands（见 herdr-plugin.toml）:
    picker   — 主 fzf picker 循环（prefix+p）
    preview  — fzf preview 渲染器（读取选中行的 TSV 字段）
    open     — 打开 picker popup pane

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
    lines = out.splitlines()
    query = lines[0] if len(lines) > 0 else ""
    key = lines[1] if len(lines) > 1 else ""
    line = lines[2] if len(lines) > 2 else ""
    return query, key, line


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


def do_resume(session_path: str, cwd: str) -> bool:
    """enter → split 新 pane（cwd=session 原 cwd）→ agent start pi --session。

    True → popup 应关闭。

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
        return False

    split_args = ["pane", "split", target_pane, "--direction", "right", "--no-focus"]
    # session 原 cwd 可能已被删除——目录不存在时不传 --cwd（让新 pane 继承当前 cwd）
    if cwd and os.path.isdir(cwd):
        split_args += ["--cwd", cwd]
    data = herdr(*split_args, timeout=15)
    if data is None:
        warn(f"pane split 失败: {target_pane}（当前 pane 不可分割？）")
        return False
    pane_id = data.get("result", {}).get("pane", {}).get("pane_id")
    if not pane_id:
        warn("pane split 未返回 pane_id")
        return False

    name = f"resume-{int(time.time())}"
    print(f"{COLOR_GRAY}正在启动 pi (session {session_path})…{RESET}", file=sys.stderr)
    ap = herdr(
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
    )
    if ap is None:
        warn(
            f"agent start 失败或超时（{AGENT_START_TIMEOUT}s）：pane {pane_id}\n"
            "pane 需处于空闲 shell 提示符才能启动 pi。"
        )
        return False
    return True


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
