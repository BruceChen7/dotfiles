# Dotfiles Configuration Repository

This repository contains my personal configuration files (dotfiles) for various command-line tools, shells, and applications. The configurations are organized by application in separate directories.

## Directory Structure

### Shell and Terminal Configuration

- **.emacs.d/** - Emacs editor configuration
  - `init.el` - Main Emacs configuration file
  - Contains basic Emacs settings and plugin configurations

- **.zshrc** - Zsh shell configuration file
  - Defines shell aliases, functions, paths, and environment variables
  - Includes theme and plugin management configurations

- **.tmux.conf** - Tmux session manager configuration
  - Defines keyboard shortcuts and window management settings
  - Includes status bar display and color theme configurations

### Version Control

- **.gitconfig** - Git version control system configuration
  - User information settings
  - Aliases and default behavior configuration
  - Colors and interface settings

- **.ssh/** - SSH secure connection configuration
  - `config` - SSH connection configuration file
  - Contains host aliases and connection settings

- **tig/** - Text-mode interface for Git
  - Provides interactive Git history browsing
  - Configuration file in `tig/config`

### Editor Configuration

- **.vim/** - Vim editor configuration
  - `asc/` - Custom plugins and configuration directory
    - `config.vim` - Basic configuration
    - `keymaps.vim` - Key mappings
    - `misc.vim` - Miscellaneous settings
    - `plugin.vim` - Plugin management
  - `colors/` - Color theme files
  - `coc-settings.json` - coc.nvim plugin configuration
  - `tasks.ini` - Task configuration

- **.vimrc** - Main Vim configuration file
  - Global Vim settings and key mappings

- **nvim/** - Neovim editor configuration
  - `init.lua` - Main Neovim configuration file
  - `lua/config/` - Various plugin configurations
    - `lsp.lua` - Language Server Protocol configuration
    - `cmp.lua` - Auto-completion configuration
    - `telescope.lua` - File search configuration
    - `gitsigns.lua` - Git signs configuration
  - `lua/plugins.lua` - Plugin management configuration
  - `lazy-lock.json` - Plugin version lock file

- **zed/** - Zed code editor configuration
  - `keymap.json` - Key mapping configuration
  - `settings.json` - Editor settings configuration

### Terminal Emulators

- **alacritty/** - Alacritty terminal emulator configuration
  - `alacritty.yml` - Terminal appearance and behavior configuration

- **foot/** - Wayland terminal emulator configuration
  - `foot.ini` - Terminal settings file

- **ghostty/** - GPU-accelerated terminal emulator configuration
  - `config` - Terminal configuration file

- **kitty/** - Cross-platform terminal emulator configuration
  - `kitty.conf` - Main terminal configuration file
  - `toggle_term.py` - Terminal toggle script

- **wezterm/** - GPU-accelerated terminal configuration
  - `wezterm.lua` - Main terminal configuration file

### Application Launchers

- **rofi/** - Application launcher configuration
  - `config.rasi` - Rofi appearance and behavior configuration

### Key Mapping and Shortcuts

- **.hammerspoon/** - macOS automation tool configuration
  - `init.lua` - Main Hammerspoon configuration file
  - `modules/` - Feature modules
    - `application.lua` - Application management
    - `hotkey.lua` - Global hotkeys
    - `window.lua` - Window management
    - `network.lua` - Network shortcuts
    - `input-method.lua` - Input method switching
    - `emoji.lua` - Emoji insertion
    - `menu.lua` - Custom menus
    - `remind.lua` - Reminder functionality
    - `password.lua` - Password management

- **kanata/** - Key remapping tool configuration
  - `esc.kbd` - Key mapping configuration file

### Development Tools

- **atuin/** - Shell history enhancer
  - `config.toml` - Atuin configuration file
  - Provides cross-shell history search and synchronization

- **starship/** - Cross-shell prompt
  - `starship.toml` - Prompt configuration
  - Custom prompt display and icons

- **zls/** - Zig Language Server
  - `zls.json` - Zig Language Server configuration

### Other Tools

- **.local/bin/** - Local executables
  - `tmux_kill_window_to_right.sh` - Tmux window management script

- **claude-code/** - Claude Code CLI configuration
  - `config.json` - Claude Code configuration
  - `plugins/` - Plugin directory

- **mcphup/** - Unknown purpose configuration
  - `servers.json` - Server configuration file

## Usage

These configuration files typically need to be symlinked to their respective locations in the home directory. The specific setup process may vary depending on the tool.

### Common Setup Steps

1. Clone the repository locally
2. Create symbolic links to the home directory
3. Adjust configurations as needed
4. Restart relevant applications

## License

MIT License