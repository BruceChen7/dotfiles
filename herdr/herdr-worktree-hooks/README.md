# herdr-worktree-hooks

把 herdr 的 worktree 生命周期事件接到 [worktree-hooks](https://github.com/ming.chen/work/dotfiles/dot-local/dot-local/bin/worktree-hooks-pkg)
CLI（`~/.local/bin/worktree-hooks`，dotfiles 里的 uv 包）上：

| herdr 事件 | worktree-hooks 命令 | 时机 |
|---|---|---|
| `worktree.created` | `presetup <checkout>` | `git worktree add` 完成后（checkout 目录已存在） |
| `worktree.opened` | `presetup <checkout>` | 打开已有 checkout 时（幂等，已存在即 skip） |
| `worktree.removed` | `clean <repo_root> <checkout>` | `git worktree remove` 完成后（目录已删，显式传 source repo） |

## 安装

```bash
herdr plugin link ~/work/dotfiles/herdr/herdr-worktree-hooks
# 重启 herdr
```

依赖：`uv`（在 PATH 或 `~/.local/bin`）、`~/.local/bin/worktree-hooks`（dotfiles 的
`dot-local` 会把它链接好）。

## 行为

- **create / open**：在新 checkout 里把 source repo 的 `.pi`、`node_modules`、
  `.gitignore` symlink 进来（`worktree-hooks` 的默认产物列表；仅对**未跟踪**的
  产物生效——被 git 跟踪的文件在 checkout 时自带，会按「已存在」跳过）。
- **remove**：checkout 目录已被 `git worktree remove` 删除，默认 symlink 清理是
  无效功；此时显式传 `repo_root`（事件 JSON 的
  `data.workspace.worktree.repo_root`，`HERDR_PLUGIN_CONTEXT_JSON` 兜底）运行
  `clean`，让**项目级 plugin 钩子**（`<source_repo>/.pi/worktree-hooks/plugin.py`
  的 `clean(ctx)`）照常执行。
- 无操作条件（事件缺 path / removed 无法解析 repo_root / 未知事件）→ 日志 + 退出 0；
  真实失败 → 非零退出，`herdr plugin log` 可查。
- 无状态：不写文件、不调 herdr CLI，纯事件转发。

## 已知行为（设计取舍）

- **remove 会触发 force 确认**：presetup 建的 symlink 是 untracked 文件，
  `git worktree remove`（非 force）会以「contains modified or untracked files」
  拒绝，herdr 弹出 force 确认，确认后 `--force` 删除。任何含 untracked 文件的
  worktree 本来就会这样，不是本插件特有。
- `worktree.removed` 的 clean 只对**目录之外**的副作用有意义（plugin 钩子）；
  checkout 目录连同 symlink 已被 git 整体删除，无需（也无法）在目录内清理。

## 测试

```bash
cd ~/work/dotfiles/herdr/herdr-worktree-hooks
python3 test_hook.py        # 或 uv run python test_hook.py
```

fixture 测试用 shim 验证事件 → 参数映射（无需活 herdr）；集成测试用临时 git repo
驱动真实 `~/.local/bin/worktree-hooks`，覆盖 presetup symlink、plugin 钩子、
clean 全链路（需要 git 与 uv）。
