"""Tests for the declarative rule layer (``worktree_hooks.rules``).

分层：判据（:func:`decide` / :func:`plan` / :func:`parse_rules` /
:func:`merge_rules` / :func:`format_action`）是纯函数，直接造数据测；发现与执行
（:func:`discover` / :func:`inspect` / :func:`apply` / :func:`clean`）才碰临时目录。
"""

from __future__ import annotations

import os
import tempfile
import time
import unittest

from worktree_hooks.rules import (
    BUILTIN_RULES,
    INSTALL,
    LINK,
    LINK_ACTION,
    LINKDIR,
    LINKDIR_ACTION,
    NODE_MODULES,
    REINSTALL,
    SKIP,
    WARN,
    Action,
    Rule,
    Target,
    apply,
    build_plan,
    clean,
    decide,
    discover,
    format_action,
    inspect,
    load_rules,
    merge_rules,
    parse_rules,
    plan,
)


def _write(path: str, content: str = "") -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(content)


def _touch(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w"):
        pass


class TestDecide(unittest.TestCase):
    """decide：四个布尔 → 一个动作（纯查表）。"""

    def test_target_present_is_skip(self) -> None:
        for kind in (LINK, LINKDIR, NODE_MODULES):
            self.assertEqual(
                decide(kind, have_target=True, have_source=True), SKIP
            )

    def test_missing_target_links_from_source(self) -> None:
        self.assertEqual(
            decide(LINK, have_target=False, have_source=True), LINK_ACTION
        )
        self.assertEqual(
            decide(LINKDIR, have_target=False, have_source=True), LINK_ACTION
        )

    def test_missing_everywhere_warns_except_deps(self) -> None:
        """私参文件缺失只 warn（绝不造空文件）；依赖缺失才 npm ci。"""
        self.assertEqual(
            decide(LINK, have_target=False, have_source=False), WARN
        )
        self.assertEqual(
            decide(NODE_MODULES, have_target=False, have_source=False), INSTALL
        )

    def test_stale_deps_reinstall_even_when_present(self) -> None:
        self.assertEqual(
            decide(
                NODE_MODULES, have_target=True, have_source=True, stale=True
            ),
            REINSTALL,
        )
        # stale 只对 node_modules 有意义：别的种类在就在了。
        self.assertEqual(
            decide(LINK, have_target=True, have_source=True, stale=True), SKIP
        )


class TestPlanAndFormat(unittest.TestCase):
    def test_plan_keeps_order(self) -> None:
        targets = [
            Target("app/.nsh", Rule("**/.nsh", LINKDIR), have_source=True),
            Target("node_modules", Rule("**/node_modules", NODE_MODULES)),
        ]
        actions = plan(targets)
        self.assertEqual([a.path for a in actions], ["app/.nsh", "node_modules"])
        self.assertEqual([a.action for a in actions], [LINK_ACTION, INSTALL])

    def test_dry_run_text_matches_shell_口径(self) -> None:
        rule = Rule("**/node_modules", NODE_MODULES)
        link = Action("app/node_modules", rule, LINK_ACTION)
        self.assertEqual(
            format_action(link, source_repo="/src", worktree="/wt"),
            "would link  app/node_modules → /src/app/node_modules",
        )
        install = Action("app/node_modules", rule, INSTALL)
        self.assertEqual(
            format_action(install, source_repo="/src", worktree="/wt"),
            "would npm ci  /wt/app",
        )
        reinstall = Action("app/node_modules", rule, REINSTALL)
        self.assertIn(
            "落后于清单",
            format_action(reinstall, source_repo="/src", worktree="/wt") or "",
        )
        # skip 静默：全部铺好的第二次调用应当零输出。
        self.assertIsNone(
            format_action(
                Action("x", rule, SKIP), source_repo="/src", worktree="/wt"
            )
        )

    def test_linkdir_label(self) -> None:
        action = Action("app/.nsh", Rule("**/.nsh", LINKDIR, ("test",)), LINK_ACTION)
        self.assertEqual(
            format_action(action, source_repo="/src", worktree="/wt"),
            "would linkdir  app/.nsh → /src/app/.nsh",
        )


class TestParseAndMerge(unittest.TestCase):
    def test_parse_rules_reads_match_kind_keep(self) -> None:
        rules = parse_rules(
            {"rule": [{"match": "**/target", "kind": LINK, "keep": ["a"]}]}
        )
        self.assertEqual(rules, [Rule("**/target", LINK, ("a",))])

    def test_parse_rules_skips_bad_entries(self) -> None:
        rules = parse_rules(
            {"rule": [{"match": "**/x"}, {"match": "**/y", "kind": "nope"}]}
        )
        self.assertEqual(rules, [])

    def test_repo_rule_wins_over_builtin_same_match(self) -> None:
        repo = [Rule("**/node_modules", LINK)]
        merged = merge_rules(repo, (), BUILTIN_RULES)
        self.assertEqual(merged[0], Rule("**/node_modules", LINK))
        self.assertEqual(
            len([r for r in merged if r.match == "**/node_modules"]), 1
        )

    def test_disable_drops_builtin(self) -> None:
        merged = merge_rules((), (), BUILTIN_RULES, disabled=("**/.nsh",))
        self.assertNotIn("**/.nsh", [r.match for r in merged])

    def test_builtin_covers_pi_clients_items(self) -> None:
        """内置规则必须覆盖 pi-clients 原来那张 ITEMS 表的每一条。"""
        expected = {
            "node_modules": NODE_MODULES,
            "app/node_modules": NODE_MODULES,
            "server/worker/node_modules": NODE_MODULES,
            "app/.nsh": LINKDIR,
            "server/ops/env.local": LINK,
            ".gitignore": LINK,
        }
        with tempfile.TemporaryDirectory() as tmp:
            for rel in expected:
                os.makedirs(os.path.join(tmp, rel), exist_ok=True)
            found = dict(discover(tmp, BUILTIN_RULES))
        self.assertEqual({k: v.kind for k, v in found.items()}, expected)
        self.assertEqual(found["app/.nsh"].keep, ("test", "test-logs"))


class TestDiscover(unittest.TestCase):
    def test_prunes_nested_matches_and_vcs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "node_modules", "x", "node_modules"))
            os.makedirs(os.path.join(tmp, ".git", "node_modules"))
            pairs = dict(discover(tmp, (Rule("**/node_modules", NODE_MODULES),)))
        self.assertEqual(list(pairs), ["node_modules"])

    def test_literal_match(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            _write(os.path.join(tmp, ".gitignore"), "x\n")
            pairs = dict(discover(tmp, (Rule(".gitignore", LINK),)))
            missing = dict(discover(tmp, (Rule(".npmrc", LINK),)))
        self.assertEqual(list(pairs), [".gitignore"])
        self.assertEqual(missing, {})


class TestInspectApplyClean(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "src")
        self.worktree = os.path.join(self._tmp.name, "wt")
        os.makedirs(self.source)
        os.makedirs(self.worktree)
        # 每个用例都跑在「干净的内置规则表」下：用户机器上的全局配置不能影响断言。
        self._old_config = os.environ.get("WORKTREE_HOOKS_CONFIG")
        os.environ["WORKTREE_HOOKS_CONFIG"] = os.path.join(
            self._tmp.name, "no-such-config.toml"
        )

    def tearDown(self) -> None:
        if self._old_config is None:
            os.environ.pop("WORKTREE_HOOKS_CONFIG", None)
        else:
            os.environ["WORKTREE_HOOKS_CONFIG"] = self._old_config
        self._tmp.cleanup()

    def test_linkdir_builds_real_dir_with_child_links(self) -> None:
        _write(os.path.join(self.source, "app", ".nsh", "tsconfig.json"), "{}\n")
        _write(os.path.join(self.source, "app", ".nsh", "test", "keep.txt"), "x\n")

        actions = build_plan(self.source, self.worktree)
        apply(self.source, self.worktree, actions)

        dst = os.path.join(self.worktree, "app", ".nsh")
        self.assertFalse(os.path.islink(dst), "目录本身必须是真目录")
        self.assertTrue(os.path.islink(os.path.join(dst, "tsconfig.json")))
        # keep 名单里的产物目录不链：nsh 自己往里写，链接会把根算到主 checkout。
        self.assertFalse(os.path.lexists(os.path.join(dst, "test")))

    def test_link_is_idempotent_and_quiet(self) -> None:
        _write(os.path.join(self.source, "server", "ops", "env.local"), "A=1\n")
        actions = build_plan(self.source, self.worktree)
        apply(self.source, self.worktree, actions)

        again = build_plan(self.source, self.worktree)
        self.assertTrue(all(a.action == SKIP for a in again))

    def test_dry_run_touches_nothing(self) -> None:
        _write(os.path.join(self.source, "node_modules", "x.js"), "")
        actions = build_plan(self.source, self.worktree)
        result = apply(self.source, self.worktree, actions, dry_run=True)
        self.assertFalse(os.path.lexists(os.path.join(self.worktree, "node_modules")))
        self.assertEqual(result.linked, 0)

    def test_legacy_whole_dir_symlink_is_rebuilt(self) -> None:
        _write(os.path.join(self.source, "app", ".nsh", "tsconfig.json"), "{}\n")
        dst = os.path.join(self.worktree, "app", ".nsh")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        os.symlink(os.path.join(self.source, "app", ".nsh"), dst)

        targets = inspect(self.source, self.worktree, discover(self.source, load_rules(self.source)))
        self.assertFalse(
            [t for t in targets if t.path == "app/.nsh"][0].have_target,
            "整目录 symlink 必须按「没有」处理，否则老症状留着",
        )

    def test_stale_deps_detected_by_mtime(self) -> None:
        parent = os.path.join(self.source, "app")
        _write(os.path.join(parent, "package.json"), "{}\n")
        _write(os.path.join(parent, "node_modules", ".package-lock.json"), "{}\n")
        # 清单比安装标记新 = pull 到了「后来才加的依赖」
        time.sleep(0.01)
        _write(os.path.join(parent, "package.json"), '{"dependencies":{}}\n')

        targets = inspect(
            self.source, self.source, discover(self.source, BUILTIN_RULES)
        )
        stale = {t.path: t.stale for t in targets}
        self.assertTrue(stale["app/node_modules"])

    def test_clean_removes_only_our_links(self) -> None:
        _write(os.path.join(self.source, "server", "ops", "env.local"), "A=1\n")
        _write(os.path.join(self.source, "app", ".nsh", "tsconfig.json"), "{}\n")
        apply(self.source, self.worktree, build_plan(self.source, self.worktree))

        foreign = os.path.join(self.worktree, "foreign")
        os.symlink("/etc/hosts", foreign)
        _write(os.path.join(self.worktree, "keep.txt"), "x\n")

        result = clean(self.source, self.worktree)

        self.assertFalse(
            os.path.lexists(os.path.join(self.worktree, "server", "ops", "env.local"))
        )
        self.assertFalse(
            os.path.lexists(
                os.path.join(self.worktree, "app", ".nsh", "tsconfig.json")
            )
        )
        # 真目录与外来链接都不动
        self.assertTrue(
            os.path.isdir(os.path.join(self.worktree, "app", ".nsh"))
        )
        self.assertTrue(os.path.islink(foreign))
        self.assertTrue(os.path.isfile(os.path.join(self.worktree, "keep.txt")))
        self.assertGreater(result.cleaned, 0)

        clean(self.source, self.worktree)  # 幂等

    def test_load_rules_reads_repo_config(self) -> None:
        _write(
            os.path.join(self.source, ".pi", "worktree-hooks.toml"),
            'disable = ["**/.nsh"]\n'
            '[[rule]]\n'
            'match = "**/vendor"\n'
            'kind = "link"\n',
        )
        matches = [rule.match for rule in load_rules(self.source)]
        self.assertIn("**/vendor", matches)
        self.assertNotIn("**/.nsh", matches)


if __name__ == "__main__":
    unittest.main()
