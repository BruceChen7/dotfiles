# Dotfiles Configuration Repository

This repository contains my personal configuration files (dotfiles) for various command-line tools, shells, and applications.

## Configuration Overview

### Shell & Terminal
* `.zshrc` - Z shell configuration
* `.tmux.conf` - tmux terminal multiplexer

### Version Control & Git
* `.gitconfig` - Git configuration with aliases and difftastic integration
* `.ssh/` - SSH configuration

### Editors
* `.vim/`, `.vimrc` - Vim configuration
* `nvim/` - Neovim configuration
* `.emacs.d/` - Emacs configuration
* `zed/` - Zed editor configuration

### Terminal Emulators
* `alacritty/` - Alacritty terminal
* `foot/` - Foot terminal (Wayland)
* `ghostty/` - Ghostty terminal
* `kitty/` - Kitty terminal
* `wezterm/` - WezTerm terminal

### AI & Development Tools
* `claude/` - Claude CLI configuration
* `claude-code/` - Claude Code configuration
* `codex/` - Codex configuration
* `droid/` - Droid configuration
* `mcphup/` - Mcphup configuration
* `opencode/` - OpenCode configuration

### Window Management & Utilities
* `.hammerspoon/` - Hammerspoon (macOS automation)
* `.i3/` - i3 window manager
* `kanata/` - Kanata keyboard remapping
* `rofi/` - Rofi application launcher

### Development Tools
* `atuin/` - Shell history sync
* `starship/` - Cross-shell prompt
* `tig/` - Text-mode interface for git
* `zls/` - Zig language server

### Other
* `.local/` - Local binaries and scripts
* `.crush/`, `.osgrep/` - Custom tools
* `.aider.chat.history.md`, `.aider.input.history` - Aider AI coding assistant history

## Prerequisites
- zsh (Z shell)
- git
- tmux (optional)
- neovim (optional)
- Various tools: fzf, zoxide, atuin, starship, difftastic, etc.

## Installation

Clone the repository:
```bash
git clone https://github.com/BruceChen7/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

Create symbolic links manually using GNU Stow or symlink individual configs:
```bash
# Using stow (recommended)
stow -t ~ .

# Or manually symlink specific configs
ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.tmux.conf ~/.tmux.conf
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/.vimrc ~/.vimrc
ln -s ~/.dotfiles/nvim ~/.config/nvim
ln -s ~/.dotfiles/alacritty ~/.config/alacritty
# Add other configs as needed
```

Restart your shell or run `source ~/.zshrc`

## Customization
- Edit `.zshrc` for shell customizations (aliases, environment variables, plugins)
- Modify `.gitconfig` for git settings and aliases
- Configure terminal emulators in their respective directories (alacritty, kitty, wezterm, etc.)
- Update macOS keybindings in `.hammerspoon/` or keyboard remapping in `kanata/`
- Customize prompt appearance in `starship/`
- Configure AI coding assistants (claude, opencode, etc.)

## License
MIT License