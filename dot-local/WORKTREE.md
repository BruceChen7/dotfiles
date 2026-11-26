# worktree 改动速查：dotfiles 这一侧与 pi-clients 那一侧

这份文档把「worktree 相关改动」的两半放在一起看：全局工具在 dotfiles 的 `dot-local`
包里，声明与两条消费链路在 `~/work/pi-clients/`。只讲现役链路，旧形状只作为背景。

## 一句话现状

所有入口最终都调同一个命令 `~/.local/bin/worktree-hooks presetup <checkout>`：
它按一张**内置规则表**补齐被 gitignore 的本地产物，镜像根 `.pi` 的未跟踪条目，最后跑
仓库在 TOML 里声明的命令钩子；`clean` 按同一张表收回。仓库不需要再复制 `plugin.py`
或 `ITEMS` 清单。

## 三条入口，一个收敛点

| 入口 | 怎么建目录 | presetup 怎么触发 |
| --- | --- | --- |
| herdr UI（prefix+t） | herdr | `herdr-worktree-hooks` 插件收 `worktree.created` / `worktree.opened` → `presetup`；`worktree.removed` → `clean <repo_root> <checkout>`（目录已删，source repo 只能显式传） |
| 手敲 `git worktree add` | git | 没有事件；靠 `make deps` 或手工跑 `worktree-hooks presetup` 补环境 |
| pi-clients 的应用内建 worktree | `server/worker` 直接 `git worktree add`（明确传 `--branch`） | worker 同步调 `worktree-hooks presetup`，并逐个核对 `expectations`；复用已有目录时只验不重跑 |

herdr 不再替服务端建 worktree：`server/worker/src/worktree-port.ts` 只有
`createWorktree` / `runPresetup` 两个方法；旧链路留下的空壳 workspace 已清理
（见 pi-clients `docs/adr/0012-worktree-created-by-us.md`）。

## 规则表：路径形状，不是项目事实

`worktree-hooks list` 在本机看到的生效规则（内置表，全局/仓库层都没覆盖）：

| match | kind | 补法 |
| --- | --- | --- |
| `**/node_modules` | `node_modules` | 从主 checkout 链接；源里没有就 `npm ci`；mtime 落后就地重装（cd 进真目录，不在 symlink 里装） |
| `**/.nsh` | `linkdir` | 目录本身是真目录、子项逐个链；`keep = ["test", "test-logs"]`。整目录 symlink 会让 nsh 把 app 根算到主 checkout |
| `**/env.local` | `link` | 链接 |
| `**/.pi`（嵌套，如 `tools/.pi`） | `linkdir` | 真目录 + 子项逐个链；根 `.pi` 不归规则层，走 `defaults.mirror_pi_untracked`（按 git 未跟踪视图逐条镜像） |
| `.gitignore` | `link` | 链接 |

覆盖顺序（先命中先得）：仓库级 `.pi/worktree-hooks.toml` → 全局
`~/.config/worktree-hooks/config.toml`（或 `WORKTREE_HOOKS_CONFIG` 指定）→ 内置表。
全局配置现在由本包的 `dot-local/.config/worktree-hooks/config.toml` stow 过去
（`make stow-dot-local`）：内容与内置表基线一致，跨机器共享同一份声明；
本机临时替换可设 `WORKTREE_HOOKS_CONFIG`。pi-clients 的忽略物全在这张表里。
`disable = ["<match>"]` 可以裁掉某条规则。

## 那份 TOML：pi-clients 的 `.pi/worktree-hooks.toml`

规则表表达不了「对刚建好的目录做一次判断」，所以 pi-clients 的仓库声明里**没有
`[[rule]]`**，只有一条 `[[hook]]`（原文见 `~/work/pi-clients/.pi/worktree-hooks.toml`）：

```toml
# worktree presetup 的项目级声明（worktree-hooks 读这个文件）。
#
# 只有**这个项目独有的**东西才写在这里。全局规则表（`worktree-hooks list` 可看）已经
# 覆盖了本仓库全部忽略物 —— 三份 `node_modules`、`app/.nsh`（含 `app/demo/.nsh`）、
# `server/ops/env.local`、`tools/.pi`、`.gitignore` —— 所以下面没有 `[[rule]]`。
#
# `[[hook]]` 是「对刚建好的目录做一次判断」的那类步骤，规则表表达不了：
# 建 worktree 的工具（herdr 的 UI、手敲的 `git worktree add`）会把新目录放在**基准
# 分支**上，于是这个目录里的提交会推进共享的 `refs/heads/master`，另一个盯着 master
# 的 worktree 立刻「全脏」，在落后那边 `git commit -a` 就是一次回退。
# `tools/worktree-branch.sh` 只在「分支被多个 worktree 检出」或「detached 且恰好在
# 基线顶端」时动手，其余情况零输出 —— 判据与纪律见该脚本头注释与 docs/adr/0002-*.md。
#
# （应用内建的 worktree 走 server/worker，明确传了 `--branch`，本来就有自己的分支；
#   这条钩子保护的是另外两条入口。）
[[hook]]
on = "presetup"
command = ["bash", "tools/worktree-branch.sh", "{worktree}", "{name}"]
```

格式要点（实现见 `worktree_hooks/hooks.py` / `rules.py`）：

- `command` 是 argv 数组，**不经过 shell**；占位符 `{worktree}` / `{source}` / `{name}`。
- `cwd` 可选，默认 `{worktree}`，同样支持占位符。
- 事件只有 `presetup` / `clean`；全局钩子在前、仓库钩子在后。
- 钩子失败只 warn，绝不中断 worktree 创建；`--dry-run` 只打印 argv。
- 声明读的是**主 checkout** 的 `.pi/worktree-hooks.toml`（`<source repo>`），不是新目录里的：
  `clean` 在 `git worktree remove` 之后跑，那时目录已经没了。代价是改声明要落到主 checkout
  所在分支才对之后新建的目录生效。

`[[rule]]` 的形状（一般用不到，缺件需要点名时才写）：

```toml
[[rule]]
match = "**/env.local"
kind = "link"
# kind = "linkdir" 时可写 keep = ["test", "test-logs"]
# disable = ["**/.nsh"]    # 单独一行，裁掉内置项
```

## pi-clients 的改动对 dotfiles 意味着什么

1. 旧形状是「每 repo 一份 `.pi/worktree-hooks/plugin.py` + `tools/worktree-deps.sh` 的
   `ITEMS` 表」，判据在两边各写一遍，必然漂移。现在判据收进全局工具，仓库声明只留差异
   （pi-clients ADR `docs/adr/0002-worktree-presetup-by-rules.md`）。
2. `plugin.py` 不再执行；`worktree-hooks` 见到旧文件只打迁移提示。`tools/worktree-deps.sh`
   仍在，但已不是链路的一环，只作为对照表；`tools/worktree-deps.test.sh` 第 6 段对账
   `--dry-run` 条目，漂移即红。
3. 提交侧还有一道闸：`tools/git-hooks/pre-commit` 拒绝在「分支被多个 worktree 检出」时提交，
   `make hooks` 把它装到 `<git-common-dir>/hooks`。
4. worker 不再依赖 herdr：少一类 `herdr_*` 错误，错误码收敛为 `worktree_create_failed` /
   `presetup_unavailable` / `presetup_failed` / `presetup_incomplete`；应用内建 worktree
   的 RPC 会同步等 presetup（上限 300 s）。
5. worker 侧的唯一依赖是这台机器上有 `worktree-hooks` 可执行；launchd 起的 worker PATH
   很窄，所以二进制解析用绝对路径候选表 `presetupBinCandidates`。

## dotfiles 侧的落点

| 文件 | 作用 |
| --- | --- |
| `dot-local/.config/worktree-hooks/config.toml` | 全局规则表，stow 到 `~/.config/worktree-hooks/config.toml`；不写仓库专属 `[[hook]]` |
| `dot-local/dot-local/bin/worktree-hooks` | bash 入口：`exec uv run --directory $HOME/.local/bin/worktree-hooks-pkg worktree-hooks "$@"`；由 `stow --dotfiles -t ~ dot-local` 链到 `~/.local/bin/` |
| `.../worktree-hooks-pkg/src/worktree_hooks/rules.py` | 内置规则表、glob 发现、`decide` / `plan` / `apply` / `clean`；读全局与仓库 TOML |
| `.../worktree_hooks/hooks.py` | `[[hook]]` 解析、占位符替换、执行（纯函数核心 + 薄壳） |
| `.../worktree_hooks/cli.py` | `presetup` / `clean` / `list`、`--dry-run`、旧 `plugin.py` 迁移提示 |
| `.../worktree_hooks/defaults.py` | 根 `.pi` 的未跟踪条目镜像与回收 |
| `herdr/herdr-worktree-hooks/herdr-plugin.toml` | 三个 herdr 事件 → `uv run hook.py`；安装用 `herdr plugin link ~/work/dotfiles/herdr/herdr-worktree-hooks`，之后重启 herdr |
| `herdr/herdr-worktree-hooks/hook.py` | 事件 JSON → CLI argv 的纯映射；`HERDR_WT_HOOKS_BIN` 可注入测试替身 |

注意：`herdr/herdr-worktree-hooks/README.md` 仍写着旧的 `plugin.py` 口径，以本文件和
`~/.local/bin/worktree-hooks --help` 为准。

## 常用命令

```bash
worktree-hooks list                          # 生效的规则、钩子、候选动作
worktree-hooks presetup --dry-run <checkout> # 只打印会做什么
worktree-hooks presetup <checkout>           # 铺产物 + 根 .pi 镜像 + presetup 钩子
worktree-hooks clean <repo_root> <checkout>  # 先跑 clean 钩子，再收回产物
cd ~/work/dotfiles/herdr/herdr-worktree-hooks && python3 test_hook.py
cd ~/.local/bin/worktree-hooks-pkg && uv run --with pytest python -m pytest tests -q
cd ~/work/pi-clients && make tools-test      # 对账/shim 测试；make deps 走同一个全局入口
```

新接一个 repo：通常什么都不用写（`worktree-hooks list` 看内置表够不够）。只有需要跑一条
命令时才加 `.pi/worktree-hooks.toml`，并把它加进 git（pi-clients 的 `.gitignore` 里有
`!/.pi/worktree-hooks.toml`）。
