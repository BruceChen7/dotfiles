# Dotfiles

Personal configuration files for macOS/Linux development environment.

## Structure

### Core
- `.zshrc` - Shell configuration
- `.gitconfig` - Git configuration
- `.tmux.conf` - Terminal multiplexer

### Editors & Terminals
- `nvim/` - Neovim configuration
- `alacritty/`, `wezterm/`, `kitty/`, `ghostty/` - Terminal emulators

### AI Tools
- `pi/` - AI coding assistant configuration
- `claude/`, `claude-code/` - Claude CLI configurations

### Development
- `atuin/` - Shell history sync
- `starship/` - Cross-shell prompt

### System
- `.hammerspoon/` - macOS automation
- `kanata/` - Keyboard remapping

## Quick Setup

```bash
git clone https://github.com/BruceChen7/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow -t ~ .
```

Restart shell: `exec zsh`