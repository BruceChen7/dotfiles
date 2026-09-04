#!/usr/bin/env python3
"""
Tests for session_index.py — herdr-pi-session-resume core.

Usage: uv run python test_session_index.py
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import session_index as idx


def sample_lines(
    cwd="/Users/x/work/dotfiles", sid="01a06b55", ts="2026-09-04T07:32:19.202Z"
):
    """A minimal but realistic v3 session file (header + model + 3 messages)."""
    return [
        json_dumps(
            {"type": "session", "version": 3, "id": sid, "timestamp": ts, "cwd": cwd}
        ),
        json_dumps(
            {
                "type": "model_change",
                "id": "m1",
                "parentId": None,
                "timestamp": ts,
                "provider": "cc",
                "modelId": "deepseek-v4-flash",
            }
        ),
        json_dumps(
            {
                "type": "message",
                "id": "u1",
                "parentId": "m1",
                "timestamp": ts,
                "message": {"role": "user", "content": "grill me"},
            }
        ),
        json_dumps(
            {
                "type": "message",
                "id": "a1",
                "parentId": "u1",
                "timestamp": ts,
                "message": {
                    "role": "assistant",
                    "content": [{"type": "text", "text": "好的，第一轮。"}],
                },
            }
        ),
        json_dumps(
            {
                "type": "message",
                "id": "u2",
                "parentId": "a1",
                "timestamp": ts,
                "message": {"role": "user", "content": "同意，画 HTML"},
            }
        ),
    ]


def json_dumps(obj):
    import json

    return json.dumps(obj, ensure_ascii=False)


class TestClassifySessionDir(unittest.TestCase):
    def test_normal_dir(self):
        self.assertTrue(idx.classify_session_dir("--Users-x-work-dotfiles--"))

    def test_private_tmp_excluded(self):
        self.assertFalse(idx.classify_session_dir("--private-tmp--"))

    def test_non_encoded_name(self):
        self.assertFalse(idx.classify_session_dir("sessions"))
        self.assertFalse(idx.classify_session_dir("plain-dir"))

    def test_encoded_cwd_roundtrip(self):
        self.assertEqual(idx.encoded_cwd_to_path("--Users-x-work--"), "/Users/x/work")


class TestBuildIndexFromLines(unittest.TestCase):
    def test_normal_parse(self):
        idx_obj = idx.build_index_from_lines(
            sample_lines(), path="/s/x.jsonl", mtime=100.0, size=42
        )
        self.assertIsNotNone(idx_obj)
        self.assertEqual(idx_obj.cwd, "/Users/x/work/dotfiles")
        self.assertEqual(idx_obj.sid, "01a06b55")
        self.assertEqual(idx_obj.model, "deepseek-v4-flash")
        self.assertEqual(idx_obj.first_msg, "grill me")
        self.assertEqual(idx_obj.msg_count, 3)
        # 期望值不硬编码：用 datetime 反向算同一 ISO 字符串
        import datetime

        expect = datetime.datetime.fromisoformat(
            "2026-09-04T07:32:19.202+00:00"
        ).timestamp()
        self.assertAlmostEqual(idx_obj.timestamp, expect, delta=0.01)

    def test_search_text_contains_user_and_assistant(self):
        idx_obj = idx.build_index_from_lines(
            sample_lines(), path="/s/x.jsonl", mtime=1, size=1
        )
        assert idx_obj is not None
        self.assertIn("grill me", idx_obj.search_text)
        self.assertIn("好的，第一轮。", idx_obj.search_text)

    def test_bad_line_skipped(self):
        lines = ["not json", "{}", *sample_lines()]
        idx_obj = idx.build_index_from_lines(lines, path="/s/x.jsonl", mtime=1, size=1)
        self.assertIsNotNone(idx_obj)
        assert idx_obj is not None
        self.assertEqual(idx_obj.msg_count, 3)

    def test_empty_file_returns_none(self):
        self.assertIsNone(
            idx.build_index_from_lines([], path="/s/e.jsonl", mtime=1, size=0)
        )

    def test_only_header_returns_none(self):
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            )
        ]
        self.assertIsNone(
            idx.build_index_from_lines(lines, path="/s/h.jsonl", mtime=1, size=1)
        )

    def test_thinking_and_toolcall_skipped(self):
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {"role": "user", "content": "帮我查一下"},
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {
                        "role": "assistant",
                        "content": [
                            {"type": "thinking", "thinking": "secret reasoning"},
                            {"type": "text", "text": "答案是 42"},
                        ],
                    },
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {
                        "role": "assistant",
                        "content": [
                            {
                                "type": "toolCall",
                                "name": "bash",
                                "arguments": {"command": "rm -rf /"},
                            },
                        ],
                    },
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "data": "base64...",
                                "mimeType": "image/png",
                            },
                        ],
                    },
                }
            ),
        ]
        idx_obj = idx.build_index_from_lines(lines, path="/s/t.jsonl", mtime=1, size=1)
        assert idx_obj is not None
        self.assertNotIn("secret reasoning", idx_obj.search_text)
        self.assertNotIn("rm -rf", idx_obj.search_text)
        self.assertNotIn("base64", idx_obj.search_text)
        self.assertIn("答案是 42", idx_obj.search_text)

    def test_recent_capped_at_max(self):
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            )
        ]
        for i in range(idx.MAX_INDEX_MESSAGES + 10):
            lines.append(
                json_dumps(
                    {
                        "type": "message",
                        "message": {"role": "user", "content": f"msg{i}"},
                    }
                )
            )
        idx_obj = idx.build_index_from_lines(lines, path="/s/c.jsonl", mtime=1, size=1)
        assert idx_obj is not None
        self.assertEqual(len(idx_obj.recent), idx.MAX_INDEX_MESSAGES)
        self.assertIn("msg0", idx_obj.search_text)  # 首条保留在 search 里
        self.assertNotIn("msg5", idx_obj.search_text)  # 前段非首条被裁掉
        self.assertIn(
            f"msg{idx.MAX_INDEX_MESSAGES + 9}", idx_obj.search_text
        )  # 最新一条保留

    def test_cwd_fallback_and_missing_fields(self):
        lines = [
            json_dumps(
                {"type": "message", "message": {"role": "user", "content": "hi"}}
            )
        ]
        idx_obj = idx.build_index_from_lines(
            lines, path="/s/f.jsonl", mtime=5.0, size=1
        )
        assert idx_obj is not None
        self.assertEqual(idx_obj.cwd, "")  # 无头部 → 空，shell 层用目录名 fallback
        self.assertEqual(idx_obj.timestamp, 5.0)  # mtime fallback


class TestNeedsReparse(unittest.TestCase):
    def test_no_cache(self):
        self.assertTrue(idx.needs_reparse(1.0, 10, None))

    def test_same_mtime_and_size(self):
        cached = {"mtime": 1.0, "size": 10}
        self.assertFalse(idx.needs_reparse(1.0, 10, cached))

    def test_mtime_changed(self):
        cached = {"mtime": 1.0, "size": 10}
        self.assertTrue(idx.needs_reparse(2.0, 10, cached))

    def test_size_changed(self):
        cached = {"mtime": 1.0, "size": 10}
        self.assertTrue(idx.needs_reparse(1.0, 11, cached))


class TestGroupByCwd(unittest.TestCase):
    def _mk(self, path, cwd, mtime):
        return idx.SessionIndex(
            path=path, sid="s", cwd=cwd, timestamp=mtime, mtime=mtime
        )

    def test_grouped_and_sorted(self):
        indexes = [
            self._mk("/a/old.jsonl", "/proj/alpha", 100),
            self._mk("/a/new.jsonl", "/proj/alpha", 200),
            self._mk("/b/only.jsonl", "/proj/beta", 150),
        ]
        groups = idx.group_by_cwd(indexes)
        self.assertEqual([c for c, _ in groups], ["/proj/alpha", "/proj/beta"])
        self.assertEqual(
            [i.path for i in groups[0][1]], ["/a/new.jsonl", "/a/old.jsonl"]
        )

    def test_empty_cwd_last(self):
        indexes = [
            self._mk("/b/x.jsonl", "", 300),
            self._mk("/a/y.jsonl", "/proj/a", 100),
        ]
        groups = idx.group_by_cwd(indexes)
        self.assertEqual([c for c, _ in groups], ["/proj/a", ""])


class TestBuildLines(unittest.TestCase):
    def _mk(self, path, cwd, mtime, first, recent=None):
        return idx.SessionIndex(
            path=path,
            sid="s",
            cwd=cwd,
            timestamp=mtime,
            mtime=mtime,
            first_msg=first,
            recent=recent or [("user", first)],
        )

    def test_group_header_and_rows(self):
        groups = [
            (
                "/proj/alpha",
                [self._mk("/a/1.jsonl", "/proj/alpha", 200, "首条消息内容")],
            )
        ]
        out = idx.build_lines(groups, home="/Users/x")
        lines = [l for l in out.splitlines() if l]
        self.assertEqual(len(lines), 2)
        self.assertIn("── /proj/alpha (1) ──", lines[0])
        fields = lines[1].split("\t")
        self.assertEqual(
            len(fields), 8
        )  # display+search | path | cwd | date | model | first | content | raw_cwd
        self.assertEqual(fields[1], "/a/1.jsonl")
        self.assertEqual(fields[7], "/proj/alpha")  # raw_cwd 供 ctrl-g 二次筛选
        # 全文搜索文本已并入第 1 列（fzf 不搜隐藏字段）
        self.assertIn("首条消息内容", fields[0])

    def test_group_header_row_has_empty_raw_cwd(self):
        groups = [("/proj/alpha", [self._mk("/a/1.jsonl", "/proj/alpha", 200, "hi")])]
        out = idx.build_lines(groups, home="/Users/x")
        fields = out.splitlines()[0].split("\t")
        self.assertEqual(len(fields), 8)
        self.assertEqual(fields[1], "")  # 组头行 path 为空
        self.assertEqual(fields[7], "")  # 组头行 raw_cwd 为空

    def test_empty_result(self):
        self.assertEqual(idx.build_lines([], home="/"), "")

    def test_unknown_cwd_label(self):
        groups = [("", [self._mk("/a/1.jsonl", "", 200, "hi")])]
        out = idx.build_lines(groups, home="/")
        self.assertIn("未知目录", out.splitlines()[0])

    def test_search_field_capped(self):
        big = "x" * 5000
        groups = [
            ("/p", [self._mk("/a/1.jsonl", "/p", 200, "hi", recent=[("user", big)])])
        ]
        out = idx.build_lines(groups, home="/")
        fields = out.splitlines()[1].split("\t")
        self.assertLessEqual(len(fields[0]), 4025)  # summary + 4000 cap + 省略号


class TestPreviewText(unittest.TestCase):
    def test_group_header_preview(self):
        out = idx.preview_text("── ~/proj (2) ──\t\t\t\t\t\t")
        self.assertIn("── ~/proj (2) ──", out)

    def test_session_row_preview(self):
        content = idx.CONTENT_SEP.join(["user: 问题内容", "assistant: 回复内容"])
        line = f"d\t/a/1.jsonl\t~/proj\t09-04 07:32\tm\t首条\t{content}"
        out = idx.preview_text(line)
        self.assertIn("/a/1.jsonl", out)  # 信息区文件
        self.assertIn("首条", out)  # 标题
        self.assertIn("问题内容", out)  # 内容区 user 消息
        self.assertIn("回复内容", out)  # 内容区 assistant 消息
        self.assertIn("session 信息", out)  # 底部信息条

    def test_preview_info_bar(self):
        line = "d\t/s/2026-09-04T07-32-19-202Z_01a06b55-2c82-735e-9f26-4411af904df4.jsonl\t~/work\t09-04 07:32\tm\t首条\t"
        out = idx.preview_text(line)
        self.assertIn("01a06b55-2c82-735e-9f26-4411af904df4", out)  # sid 从文件名提取
        self.assertIn("cwd:     ~/work", out)

    def test_empty_line(self):
        self.assertEqual(idx.preview_text(""), "")


class TestScopeGroups(unittest.TestCase):
    """ctrl-g 二次筛选（仿 snacks.nvim grep picker 的 <c-g>=tcd+picker_grep）。"""

    def _mk(self, path, cwd, mtime):
        return idx.SessionIndex(
            path=path, sid="s", cwd=cwd, timestamp=mtime, mtime=mtime
        )

    def _groups(self):
        return [
            ("/proj/alpha", [self._mk("/a/1.jsonl", "/proj/alpha", 200)]),
            ("/proj/beta", [self._mk("/b/1.jsonl", "/proj/beta", 150)]),
        ]

    def test_filter_to_one_cwd(self):
        groups = idx.scope_groups(self._groups(), "/proj/alpha")
        self.assertEqual([c for c, _ in groups], ["/proj/alpha"])
        self.assertEqual(len(groups[0][1]), 1)

    def test_empty_cwd_returns_all(self):
        """空 cwd（组头行 / alt-g 恢复全量）→ 原样返回。"""
        groups = self._groups()
        self.assertEqual(idx.scope_groups(groups, ""), groups)

    def test_unknown_cwd_returns_empty(self):
        self.assertEqual(idx.scope_groups(self._groups(), "/no/such"), [])


class TestRedactAndFmt(unittest.TestCase):
    def test_redact_path(self):
        self.assertEqual(idx.redact_path("/Users/x/work", "/Users/x"), "~/work")
        self.assertEqual(idx.redact_path("/Users/x", "/Users/x"), "~")
        self.assertEqual(idx.redact_path("/opt/app", "/Users/x"), "/opt/app")

    def test_fmt_timestamp(self):
        self.assertEqual(idx.fmt_timestamp(1759577539.202)[:5], "10-04")
        self.assertEqual(idx.fmt_timestamp(0)[:5], "01-01")
        self.assertEqual(idx.fmt_timestamp(-1), "--")


class TestParseContextPaneId(unittest.TestCase):
    def test_extracts_focused_pane_id(self):
        ctx = json_dumps({"workspace_id": "w1", "focused_pane_id": "w1:p2"})
        self.assertEqual(idx.parse_context_pane_id(ctx), "w1:p2")

    def test_none_and_empty(self):
        self.assertEqual(idx.parse_context_pane_id(None), "")
        self.assertEqual(idx.parse_context_pane_id(""), "")

    def test_invalid_json(self):
        self.assertEqual(idx.parse_context_pane_id("not json"), "")

    def test_missing_field(self):
        self.assertEqual(
            idx.parse_context_pane_id(json_dumps({"workspace_id": "w1"})), ""
        )

    def test_non_dict(self):
        self.assertEqual(idx.parse_context_pane_id('["w1:p2"]'), "")


class TestStripSkillBlocks(unittest.TestCase):
    def test_plain_text_unchanged(self):
        self.assertEqual(idx.strip_skill_blocks("grill me"), "grill me")

    def test_skill_block_stripped(self):
        text = (
            '前文 <skill name="x" location="/p/x/SKILL.md">\nbody here\n</skill> 后文'
        )
        out = idx.strip_skill_blocks(text)
        self.assertNotIn("<skill", out)
        self.assertNotIn("body here", out)
        self.assertIn("前文", out)
        self.assertIn("后文", out)

    def test_available_skills_list_stripped(self):
        text = "x\n<available_skills>\n  <skill><name>a</name></skill>\n</available_skills>\ny"
        out = idx.strip_skill_blocks(text)
        self.assertNotIn("available_skills", out)
        self.assertNotIn("<name>a</name>", out)
        self.assertIn("x", out)
        self.assertIn("y", out)

    def test_self_closing_skill_stripped(self):
        out = idx.strip_skill_blocks('a <skill name="z" location="/p"/> b')
        self.assertNotIn("<skill", out)
        self.assertIn("a", out)
        self.assertIn("b", out)

    def test_empty_text(self):
        self.assertEqual(idx.strip_skill_blocks(""), "")
        self.assertIsNone(idx.strip_skill_blocks(None))


class TestTruncateUserLines(unittest.TestCase):
    def test_short_message_unchanged(self):
        self.assertEqual(idx.truncate_user_lines("grill me"), "grill me")
        self.assertEqual(idx.truncate_user_lines("line1\nline2"), "line1\nline2")

    def test_long_message_dropped(self):
        """> max_lines 行 → 整条返回空（模板/长粘贴不入索引）。"""
        text = "line1\nline2\nline3\nline4"
        self.assertEqual(idx.truncate_user_lines(text), "")

    def test_template_like_body_dropped(self):
        """几十行模板正文（含标题行）→ 整条排除。"""
        tpl = "".join(f"line{i}\n" for i in range(1, 40))
        self.assertEqual(idx.truncate_user_lines(tpl), "")

    def test_heading_only_template_dropped(self):
        """模板标题行 + 空行 + 正文 → 超过 2 行，整条排除（方案 B）。"""
        tpl = (
            "# Article Buddy — 大白话讲文章 + 唠嗑式拷问\n\n面向有一定技术基础的读者\n"
        )
        self.assertEqual(idx.truncate_user_lines(tpl), "")

    def test_empty(self):
        self.assertEqual(idx.truncate_user_lines(""), "")
        self.assertIsNone(idx.truncate_user_lines(None))


class TestBuildIndexTemplateAndSkillCleanup(unittest.TestCase):
    def test_user_message_dropped_in_index(self):
        """模板样长 user 首条（>2 行）→ 整条不入索引，真实对话仍可搜。"""
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {
                        "role": "user",
                        "content": "line1\nline2\nline3\nline4",
                    },
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {"role": "assistant", "content": "真实回复全文"},
                }
            ),
        ]
        index = idx.build_index_from_lines(lines, path="/s/t.jsonl", mtime=1, size=1)
        assert index is not None
        self.assertNotIn("line1", index.search_text)
        self.assertNotIn("line3", index.search_text)
        self.assertNotIn("line4", index.search_text)
        # assistant 不截断
        self.assertIn("真实回复全文", index.search_text)

    def test_short_user_message_kept_as_first(self):
        """模板长首条被丢弃后，后续短 user 消息成为 first_msg。"""
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {"role": "user", "content": "模板\n模板2\n模板3\n模板4"},
                }
            ),
            json_dumps(
                {"type": "message", "message": {"role": "user", "content": "go ahead"}}
            ),
            json_dumps(
                {"type": "message", "message": {"role": "assistant", "content": "好的"}}
            ),
        ]
        index = idx.build_index_from_lines(lines, path="/s/t2.jsonl", mtime=1, size=1)
        assert index is not None
        self.assertEqual(index.first_msg, "go ahead")
        self.assertIn("go ahead", index.search_text)

    def test_all_messages_long_returns_none(self):
        """首条 + 全部消息都是长模板 → 无有效文本 → None（不入索引）。"""
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {"role": "user", "content": "a\nb\nc\nd\ne"},
                }
            ),
        ]
        self.assertIsNone(
            idx.build_index_from_lines(lines, path="/s/l.jsonl", mtime=1, size=1)
        )

    def test_skill_blocks_stripped_from_all_messages(self):
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {
                        "role": "user",
                        "content": '<skill name="s1" location="/p/SKILL.md">\nskill body\n</skill> 真实提问',
                    },
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {
                        "role": "assistant",
                        "content": "回复 <available_skills>a</available_skills> 完成",
                    },
                }
            ),
        ]
        index = idx.build_index_from_lines(lines, path="/s/s.jsonl", mtime=1, size=1)
        assert index is not None
        self.assertNotIn("skill body", index.search_text)
        self.assertNotIn("s1", index.search_text)
        self.assertNotIn("available_skills", index.search_text)
        self.assertIn("真实提问", index.search_text)
        self.assertIn("完成", index.search_text)

    def test_short_user_message_kept(self):
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {"type": "message", "message": {"role": "user", "content": "grill me"}}
            ),
        ]
        index = idx.build_index_from_lines(lines, path="/s/u.jsonl", mtime=1, size=1)
        assert index is not None
        self.assertIn("grill me", index.search_text)
        self.assertEqual(index.first_msg, "grill me")

    def test_msg_count_counts_kept_messages(self):
        """长 user 消息（>2 行）被丢弃，msg_count 只统计保留的消息。"""
        lines = [
            json_dumps(
                {
                    "type": "session",
                    "id": "x",
                    "cwd": "/tmp",
                    "timestamp": "2026-09-04T07:32:19Z",
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {"role": "user", "content": "a\nb\nc\nd"},
                }
            ),
            json_dumps(
                {
                    "type": "message",
                    "message": {"role": "assistant", "content": "reply"},
                }
            ),
        ]
        index = idx.build_index_from_lines(lines, path="/s/m.jsonl", mtime=1, size=1)
        assert index is not None
        self.assertEqual(index.msg_count, 1)


class TestCachePayloadMerge(unittest.TestCase):
    def test_roundtrip(self):
        index = idx.SessionIndex(
            path="/a.jsonl", sid="s", cwd="/p", timestamp=1.0, mtime=1.0, size=2
        )
        payload = idx.cache_payload([index])
        restored = idx.SessionIndex.from_dict(payload["/a.jsonl"]["index"])
        self.assertEqual(restored.path, "/a.jsonl")
        self.assertEqual(restored.cwd, "/p")

    def test_merge_overwrites_same_path(self):
        a = idx.SessionIndex(
            path="/a.jsonl", sid="1", cwd="/p", timestamp=1.0, mtime=1.0, size=2
        )
        b = idx.SessionIndex(
            path="/a.jsonl", sid="2", cwd="/p", timestamp=2.0, mtime=2.0, size=3
        )
        merged = idx.cache_merge({"old": {"mtime": 0, "size": 0, "index": {}}}, [a, b])
        self.assertIn("old", merged)
        self.assertEqual(merged["/a.jsonl"]["mtime"], 2.0)


if __name__ == "__main__":
    unittest.main()
