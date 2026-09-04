#!/usr/bin/env python3
"""
session_index.py — herdr-pi-session-resume 核心（纯函数，value in / value out）。

职责：把 pi session JSONL 解析成可搜索索引，按 cwd 分组，渲染 fzf 行与
preview 详情。本文件不含 herdr CLI / fzf / 剪贴板等副作用（那些在 picker.py）。

数据格式（pi session，v3，见 docs/session-format.md）：
    ~/.pi/agent/sessions/--<encoded-cwd>--/<timestamp>_<uuid>.jsonl
    每行一个 JSON：type=session 头部(id/cwd/timestamp/version)、
    type=message 消息(message.role + message.content 文本或 blocks)、
    type=model_change(modelId)、type=thinking_level_change、type=custom 等。

索引规则（spec 已定）：
    - 索引字段 = user 文本 + assistant text 块；跳过 thinking/toolCall/image base64。
    - 每 session 只保留最近 MAX_INDEX_MESSAGES 条消息的文本做全文搜索。
    - 容错：坏行跳过、超大文件截断、无 session 头部则返回 None。
    - 增量：缓存按 (mtime, size) 判定是否需要重解析。
"""

import json
import re
from dataclasses import dataclass, field
from datetime import datetime

MAX_INDEX_MESSAGES = 30
MAX_FILE_BYTES = 5 * 1024 * 1024  # 单文件读取上限 5MB
MAX_USER_INPUT_LINES = 2  # user 消息索引只取前 2 行（模板长正文自然排除）

# 索引逻辑版本：解析/剥离/截断逻辑变化时 +1 → picker 检测到不匹配会全量重建缓存。
# 增量缓存按 (mtime, size) 判定，代码改了但 session 文件没变时缓存永远不会失效，
# 必须靠这个版本号强制重建（2026-09-04 踩坑：改截断逻辑后用户仍看到旧索引）。
INDEX_LOGIC_VERSION = 2

# 目录名以这些前缀开头 → 视为临时/私有，跳过（--private-tmp-- 等）
EXCLUDE_DIR_PREFIXES = ("--private-", "--var-", "--tmp-")

# skill 注入块（pi 的 _expandSkillCommand / formatSkillsForPrompt 生成格式）
SKILL_BLOCK_RE = re.compile(r"<skill\s+[^>]*>.*?</skill>", re.DOTALL)
AVAILABLE_SKILLS_RE = re.compile(r"<available_skills>.*?</available_skills>", re.DOTALL)
SKILL_SELFCLOSE_RE = re.compile(r"<skill\s+[^>]*/>")


# ---- 数据模型 ---------------------------------------------------------------


@dataclass
class SessionIndex:
    path: str  # jsonl 绝对路径
    sid: str  # session id（头部 id 字段；缺失用文件名 uuid）
    cwd: str  # 头部 cwd 字段；缺失用目录名反解（fallback）
    timestamp: float  # 头部 timestamp 的 epoch 秒；缺失用文件 mtime
    model: str = ""  # 最后一个 model_change 的 modelId
    first_msg: str = ""  # 第一条 user 消息全文
    recent: list = field(default_factory=list)  # [(role, text)] 最近 N 条消息
    msg_count: int = 0  # 消息条目数（user + assistant）
    mtime: float = 0.0  # 文件 mtime（缓存判定 + 组内排序）
    size: int = 0  # 文件 size（缓存判定）

    @property
    def search_text(self) -> str:
        """全文搜索字段：首条 + 最近消息文本（cap 由 recent 已保证）。"""
        parts = [self.first_msg] + [t for _, t in self.recent]
        return "\n".join(p for p in parts if p)

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "sid": self.sid,
            "cwd": self.cwd,
            "timestamp": self.timestamp,
            "model": self.model,
            "first_msg": self.first_msg,
            "recent": self.recent,
            "msg_count": self.msg_count,
            "mtime": self.mtime,
            "size": self.size,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "SessionIndex":
        return cls(
            path=d.get("path", ""),
            sid=d.get("sid", ""),
            cwd=d.get("cwd", ""),
            timestamp=float(d.get("timestamp", 0) or 0),
            model=d.get("model", ""),
            first_msg=d.get("first_msg", ""),
            recent=list(d.get("recent", []) or []),
            msg_count=int(d.get("msg_count", 0) or 0),
            mtime=float(d.get("mtime", 0) or 0),
            size=int(d.get("size", 0) or 0),
        )


# ---- 纯函数：目录扫描 --------------------------------------------------------


def classify_session_dir(name: str) -> bool:
    """目录名是否是需要扫描的 session 目录（排除临时/私有前缀）。"""
    if not name.startswith("--") or not name.endswith("--"):
        return False
    return not any(name.startswith(p) for p in EXCLUDE_DIR_PREFIXES)


def encoded_cwd_to_path(encoded: str) -> str:
    """目录名反解：`--Users-ming.chen-work--` → `/Users/ming.chen/work`。

    仅作 fallback（头部 cwd 优先）；`-` 可能本身出现在路径中，反解不保证
    唯一，因此只在头部缺失时使用。
    """
    return "/" + encoded.strip("-").replace("-", "/")


# ---- 纯函数：JSONL 解析 -----------------------------------------------------


def _iso_to_epoch(ts: str) -> float | None:
    """ISO 时间戳 → epoch 秒；解析失败返回 None。"""
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def extract_text_blocks(content) -> list[str]:
    """从 message.content 提取 text 文本块（跳过 thinking/toolCall/image）。"""
    if isinstance(content, str):
        return [content] if content else []
    if not isinstance(content, list):
        return []
    out = []
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "text" and block.get("text"):
            out.append(str(block["text"]))
        # thinking / toolCall / image 等 block 一律跳过
    return out


def message_text(msg: dict) -> str:
    """单条 message 的全部 text 文本（blocks 拼接）。"""
    content = msg.get("content")
    blocks = extract_text_blocks(content)
    return "\n".join(b for b in blocks if b)


def strip_skill_blocks(text: str) -> str:
    """剥离 skill 块/列表/自闭合引用（全部消息），返回纯对话文本。

    pi 注入格式（_expandSkillCommand / formatSkillsForPrompt）：
      <skill name="..." location="...">...body...</skill>
      <available_skills>...</available_skills>
      <skill .../>  自闭合引用
    """
    if not text:
        return text
    out = AVAILABLE_SKILLS_RE.sub("", text)
    out = SKILL_BLOCK_RE.sub("", out)
    out = SKILL_SELFCLOSE_RE.sub("", out)
    return out


def truncate_user_lines(text: str, max_lines: int = MAX_USER_INPUT_LINES) -> str:
    """user 消息索引策略（格式无关，通用规则）：

    消息 ≤ max_lines 行 → 原样保留（用户真实输入几乎都短）；
    消息 > max_lines 行 → 返回空串（= 模板/长粘贴，整条不入索引）。

    不做任何模板形态识别（不认 `#` 标题、不认 "IMPORTANT:"、不认 `${@}` 占位符）——
    只看长度：长输入 = 样板文字 = 噪音。模板几十行正文、标题行、参数替换
    一律不进入 search_text / first_msg。
    """
    if not text:
        return text
    lines = text.split("\n")
    if len(lines) > max_lines:
        return ""
    return text


def build_index_from_lines(
    lines, *, path: str, mtime: float, size: int
) -> SessionIndex | None:
    """从 JSONL 行序列构建 SessionIndex（纯函数，容错）。

    规则：
      - type=session 行提供 id / cwd / timestamp；缺失时降级。
      - type=message 行：role ∈ {user, assistant} 计入；text 块为索引文本。
      - 其他 type（model_change 记 model；thinking_level_change/custom 等跳过）。
      - 坏行跳过；无任何消息 → None。
      - recent 只保留最近 MAX_INDEX_MESSAGES 条。
    """
    sid = ""
    cwd = ""
    timestamp: float | None = None
    model = ""
    msgs: list[tuple[str, str]] = []
    first_user = ""
    msg_count = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(obj, dict):
            continue
        t = obj.get("type")
        if t == "session":
            sid = str(obj.get("id") or "")
            cwd = str(obj.get("cwd") or "")
            ts = _iso_to_epoch(str(obj.get("timestamp") or ""))
            if ts is not None:
                timestamp = ts
        elif t == "model_change":
            mid = obj.get("modelId")
            if mid:
                model = str(mid)
        elif t == "message":
            msg = obj.get("message")
            if not isinstance(msg, dict):
                continue
            role = msg.get("role")
            if role not in ("user", "assistant"):
                continue
            text = message_text(msg)
            if not text:
                continue
            # 剥离 skill 块（全部消息）；user 消息再截断到前 MAX_USER_INPUT_LINES 行
            text = strip_skill_blocks(text)
            if role == "user":
                text = truncate_user_lines(text)
            if not text:
                continue
            msg_count += 1
            msgs.append((str(role), text))
            if role == "user" and not first_user:
                first_user = text

    if not msgs and not first_user:
        return None

    recent = msgs[-MAX_INDEX_MESSAGES:]
    if timestamp is None:
        timestamp = mtime
    return SessionIndex(
        path=path,
        sid=sid or _path_fallback_id(path),
        cwd=cwd or "",
        timestamp=timestamp,
        model=model,
        first_msg=first_user,
        recent=recent,
        msg_count=msg_count,
        mtime=mtime,
        size=size,
    )


def _path_fallback_id(path: str) -> str:
    """文件名 <timestamp>_<uuid>.jsonl 里的 uuid 段；失败返回空。"""
    import os

    m = re.match(r".*_[0-9a-fA-F-]{8,}\.jsonl$", os.path.basename(path))
    if not m:
        return ""
    return os.path.basename(path).rsplit(".", 1)[0].split("_", 1)[-1]


def cwd_fallback(encoded_dir: str) -> str:
    """目录名反解 cwd（头部缺失时由 shell 层调用）。"""
    return encoded_cwd_to_path(encoded_dir)


def parse_context_pane_id(context_json: str | None) -> str:
    """从 HERDR_PLUGIN_CONTEXT_JSON 提取 focused_pane_id。

    插件 popup 进程**没有** HERDR_PANE_ID env（herdr 的 plugin_pane_launch_env
    只注入 HERDR_PLUGIN_CONTEXT_JSON），所以 split 目标 pane 必须从这里取——
    它记录的是用户打开 popup 前聚焦的 pane。
    """
    if not context_json:
        return ""
    try:
        ctx = json.loads(context_json)
    except (json.JSONDecodeError, TypeError):
        return ""
    if not isinstance(ctx, dict):
        return ""
    pid = ctx.get("focused_pane_id")
    return str(pid) if pid else ""


def find_workspace_for_cwd(panes: list[dict], cwd: str) -> str | None:
    """给定 pane list（dict 含 cwd + workspace_id + focused），返回 cwd 完全
    匹配的 workspace_id；优先 focused workspace，否则第一个匹配；无匹配
    返回 None。cwd 为空 / panes 为空 → None。

    用途：resume 时判断 session 原 cwd 是否已有专属 space——workspace 本身
    不暴露 cwd（WorkspaceInfo 无该字段），pane list 的 cwd + workspace_id
    是可靠来源。
    """
    if not cwd or not panes:
        return None
    fallback: str | None = None
    for pane in panes:
        if not isinstance(pane, dict):
            continue
        if pane.get("cwd") != cwd:
            continue
        wid = pane.get("workspace_id")
        if not wid:
            continue
        wid = str(wid)
        if pane.get("focused"):
            return wid
        if fallback is None:
            fallback = wid
    return fallback


# ---- 纯函数：增量缓存判定 ---------------------------------------------------


def needs_reparse(mtime: float, size: int, cached: dict | None) -> bool:
    """mtime/size 任一变化 → 需要重解析；无缓存 → 需要。"""
    if cached is None:
        return True
    return (
        abs(float(cached.get("mtime", -1)) - mtime) > 1e-6
        or int(cached.get("size", -1)) != size
    )


def cache_payload(indexes: list[SessionIndex]) -> dict:
    """索引列表 → 可 JSON 序列化的缓存负载。"""
    return {
        i.path: {"mtime": i.mtime, "size": i.size, "index": i.to_dict()}
        for i in indexes
    }


def cache_merge(cache: dict, fresh: list[SessionIndex]) -> dict:
    """合并：新鲜索引覆盖对应 path，其余保留（供 shell 层原子写回）。"""
    merged = dict(cache or {})
    for i in fresh:
        merged[i.path] = {"mtime": i.mtime, "size": i.size, "index": i.to_dict()}
    return merged


# ---- 纯函数：分组与渲染 ------------------------------------------------------


def group_by_cwd(indexes: list[SessionIndex]) -> list[tuple[str, list[SessionIndex]]]:
    """按 cwd 分组：组间按最近活动（组内最大 mtime）倒序，组内按 mtime 倒序。

    无 cwd 的 session 归入 "" 组（渲染为 "未知目录"），排在最后。
    """
    groups: dict[str, list[SessionIndex]] = {}
    for idx in indexes:
        groups.setdefault(idx.cwd, []).append(idx)
    items = sorted(
        groups.items(),
        key=lambda kv: (-max(i.mtime for i in kv[1]), kv[0]),
    )
    # 空 cwd 组垫底（-max 会把空组排前面，需单独处理）
    non_empty = [(c, sorted(v, key=lambda i: -i.mtime)) for c, v in items if c]
    empty = [(c, sorted(v, key=lambda i: -i.mtime)) for c, v in items if not c]
    return non_empty + empty


def scope_groups(
    groups: list[tuple[str, list[SessionIndex]]], cwd: str
) -> list[tuple[str, list[SessionIndex]]]:
    """二次筛选（ctrl-g）：只保留 cwd 匹配的组；cwd 为空 → 返回全量。

    snacks.nvim grep picker 的 `<c-g>` = tcd + picker_grep（收窄到当前项
    所在目录后重新筛选）在 session picker 里的对应物：把列表收窄到当前
    选中 session 的项目目录，fzf 重启后 query 保留，可继续输入二次筛选。
    """
    if not cwd:
        return groups
    return [(c, v) for c, v in groups if c == cwd]


def redact_path(cwd: str, home: str) -> str:
    """cwd 显示：home → ~，home 前缀 → ~/...，其余原样。"""
    if not cwd:
        return ""
    if cwd == home:
        return "~"
    if cwd.startswith(home + "/"):
        return "~" + cwd[len(home) :]
    return cwd


def fmt_timestamp(ts: float) -> str:
    """epoch 秒 → `MM-DD HH:MM`（本地时区）；非法 → `--`。"""
    if ts < 0:
        return "--"
    try:
        dt = datetime.fromtimestamp(ts).astimezone()
        return dt.strftime("%m-%d %H:%M")
    except (OverflowError, OSError, ValueError):
        return "--"


def _truncate(text: str, limit: int) -> str:
    """拍平为单行并截断到 limit 字符（含省略号）。"""
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "…"


def _flat_field(text: str) -> str:
    """字段内不允许换行/Tab（否则会拆散 fzf 行）。"""
    return re.sub(r"[\t\n\r]", " ", text).strip()


CONTENT_SEP = "\x1f"  # 行内消息分隔符（fzf 行不能含换行，用 Unit Separator）
CONTENT_NL = "\x1e"  # 消息内换行占位（Record Separator；preview 解码回 \n）


def _content_field(recent: list) -> str:
    """recent [(role, text)] → 单字段：`user: text\x1fuser: text`。

    消息间用 CONTENT_SEP 分隔；消息内换行编码为 CONTENT_NL——fzf 行必须
    是单行，preview 解析时把 CONTENT_NL 解码回换行以完整展示消息。
    """
    return CONTENT_SEP.join(
        f"{role}: {text.replace(chr(10), CONTENT_NL).replace(chr(9), ' ').strip()}"
        for role, text in recent
    )


def build_lines(groups: list[tuple[str, list[SessionIndex]]], home: str) -> str:
    """渲染 fzf 行（TSV，第 1 列显示，其余列供 preview/动作）：

        display+search \t path \t cwd \t date \t model \t first \t content \t raw_cwd

    组头行：display = `── <cwd> (N) ──`，path 为空（选中组头无动作）。
    组内第 1 列 = `MM-DD HH:MM · <cwd> · <首条消息截断>` + 全文搜索文本——
    fzf 只搜索变换后行（隐藏字段不可搜），所以全文必须并入第 1 列；
    显示时 fzf 自动截断到终端宽度，搜索则匹配整列。
    preview 的 `{}` 是原始行（字段可解析）。
    content 列 = 完整消息（带 role），供 preview 展示全部内容。
    raw_cwd 列 = 未 redact 的原始 cwd，供 ctrl-g 二次筛选（scope）精确匹配。
    """
    lines = []
    for cwd, indexes in groups:
        label = redact_path(cwd, home) if cwd else "未知目录"
        head = f"── {label} ({len(indexes)}) ──"
        lines.append(f"{head}\t\t\t\t\t\t\t")
        for idx in indexes:
            summary = (
                f"{fmt_timestamp(idx.timestamp)} · {redact_path(idx.cwd, home)}"
                f" · {_truncate(idx.first_msg, 60)}"
            )
            search = _flat_field(idx.search_text)
            if len(search) > 4000:  # 行级 cap，防 fzf 单行过大
                search = search[:4000] + "…"
            display = f"{summary}  {search}"
            lines.append(
                "\t".join(
                    [
                        display,
                        idx.path,
                        redact_path(idx.cwd, home),
                        fmt_timestamp(idx.timestamp),
                        idx.model,
                        _truncate(idx.first_msg, 200),
                        _content_field(idx.recent),
                        idx.cwd,
                    ]
                )
            )
    if not lines:
        return ""
    return "\n".join(lines) + "\n"


# ---- 纯函数：preview 详情 ----------------------------------------------------


def preview_text(line: str) -> str:
    """fzf preview 渲染（方案 A：完整内容在上 + session 信息在下）。

    行 = build_lines 的 TSV（7 列）；组头行(path 空)只显示分组标题。
    内容区显示 content 列（带 role 的完整消息，按 CONTENT_SEP 拆回）；
    信息区固定在底部（session id / cwd / model / 消息数 / 时间 / 文件）。
    """
    if not line:
        return ""
    fields = line.split("\t")
    display = fields[0]
    path = fields[1] if len(fields) > 1 else ""
    if not path:
        return f"{display}\n"
    cwd = fields[2]
    date = fields[3]
    model = fields[4]
    first = fields[5] if len(fields) > 5 else ""
    content = fields[6] if len(fields) > 6 else ""

    # 内容区：完整消息（role 着色，换行解码）
    out = [f"\033[1m{_truncate(first, 120)}\033[0m", ""]
    if content:
        for seg in content.split(CONTENT_SEP):
            role, _, text = seg.partition(": ")
            text = text.replace(CONTENT_NL, "\n")
            if role == "user":
                out.append(f"\033[34muser\033[0m: {text}")
            else:
                out.append(f"\033[33massistant\033[0m: {text}")
    out.append("")

    # 信息区（底部固定）
    out.append("\033[90m──── session 信息 ────\033[0m")
    sid = path.rsplit("/", 1)[-1].rsplit(".", 1)[0].split("_", 1)[-1]
    out.append(f"id:      {sid}")
    out.append(f"cwd:     {cwd}")
    out.append(f"model:   {model or '-'}")
    out.append(f"时间:    {date}")
    out.append(f"文件:    {path}")
    return "\n".join(out) + "\n"
