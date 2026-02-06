# AGENTS.md

本项目使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范来编写 commit messages。

## Commit 格式规范

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

### 提交类型 (Type)

| 类型 | 描述 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 仅文档更改 |
| `style` | 不影响代码含义的更改（空格、格式化、分号等） |
| `refactor` | 重构代码，既不是新功能也不是 bug 修复 |
| `perf` | 性能优化 |
| `test` | 添加或修改测试 |
| `chore` | 构建过程或辅助工具的更改 |
| `ci` | CI 配置文件和脚本的更改 |
| `build` | 构建系统或外部依赖的更改 |

### 示例

**功能提交：**
```
feat(zsh): add new alias for git status
```

**修复提交：**
```
fix(tmux): resolve session restore issue on macOS
```

**重大变更：**
```
feat(config): add new theme support

BREAKING CHANGE: theme config format has changed
```

## 作用域 (Scope)

作用域可以是描述变更位置的任意单词：

- `zsh` - .zshrc 相关
- `git` - .gitconfig 相关
- `tmux` - .tmux.conf 相关
- `vim` - vim 配置相关
- `alacritty` - alacritty 配置
- `nvim` - neovim 配置
- 其他配置文件名

## 注意事项

1. 使用祈使句（imperative mood），例如 "add" 而不是 "added"
2. 描述首字母小写
3. body 和 footer 之间用空行分隔
4. footer 中的 breaking changes 以 `BREAKING CHANGE:` 开头

## 工具支持

推荐使用以下工具辅助生成规范 commit：

- `commitizen` - 交互式 Commit 生成工具
- `cz-cli` - Commitizen CLI
- `commitlint` - Commit message 校验

### 安装 commitizen（可选）

```bash
npm install -g commitizen cz-conventional-changelog
```

### 使用

```bash
git add .
git cz
```