# dot-local

本包管理 `~/.local/bin/` 下的脚本和工具。

## 部署

```bash
cd ~/work/dotfiles
make stow-dot-local
```

`--dotfiles` 将包内 `dot-local/` 路径重命名为 `.local/`，使目标路径正确落在 `~/.local/bin/`。
同时把 `.config/worktree-hooks/config.toml` 链到 `~/.config/worktree-hooks/config.toml`
（worktree-hooks 的全局规则表；字面 `.config/` 与 herdr 包同一写法）。

worktree 的现役链路（内置规则表、TOML 声明、pi-clients 侧的消费改动）见
[WORKTREE.md](WORKTREE.md)。

## 包含内容

- `tmux_git_branch.sh` — tmux git 分支信息
- `tmux_kill_window_to_right.sh` — 关闭右侧窗口
- `worktree-hooks` — worktree 生命周期钩子框架（入口脚本）
- `worktree-hooks-pkg/` — worktree-hooks Python 包；`presetup` 把源仓库的
  `node_modules` / `.gitignore` symlink 过来，再按 **git 未跟踪视图**
  （`git ls-files -o --directory -- .pi`）逐条镜像 `.pi` 条目，tracked 内容跟分支走
