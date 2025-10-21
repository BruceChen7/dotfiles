# Dotfiles Configuration Repository

This repository contains my personal configuration files (dotfiles) for various command-line tools, shells, and applications.

## Configuration Overview
* Shell and terminal configuration: `.zshrc`, `.tmux.conf`
* Version control: `.gitconfig`, `.ssh/`
* Editor configuration: `.vim/`, `.nvim/`
* Terminal emulators: `alacritty/`, `foot/`, `kitty/`
* Application launchers: `rofi/`
* Key mapping and shortcuts: `.hammerspoon/`, `kanata/`
* Development tools: `atuin/`, `starship/`, `zls/`

## Prerequisites
- zsh (Z shell)
- git
- tmux (optional)
- neovim (optional)
- Various tools: fzf, zoxide, atuin, starship, etc.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/BruceChen7/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

2. Run the installation script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. Restart your shell or run `source ~/.zshrc`

## Manual Setup (Alternative)
Create symbolic links manually:
```bash
ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.tmux.conf ~/.tmux.conf
# Add other files as needed
```

## Customization
- Edit `.zshrc` for shell customizations
- Modify `.gitconfig` for git settings
- Adjust terminal emulator configs in respective directories
- Update keybindings in `.zshrc` or Hammerspoon config

## License
MIT License