# dot-local

本包管理 `~/.local/bin/` 下的脚本和工具。

## 部署

```bash
cd ~/work/dotfiles
stow --dotfiles -t ~ dot-local
```

`--dotfiles` 将包内 `dot-local/` 路径重命名为 `.local/`，使目标路径正确落在 `~/.local/bin/`。

## 包含内容

- `tmux_git_branch.sh` — tmux git 分支信息
- `tmux_kill_window_to_right.sh` — 关闭右侧窗口
- `worktree-hooks` — worktree 生命周期钩子框架（入口脚本）
- `worktree-hooks-pkg/` — worktree-hooks Python 包
