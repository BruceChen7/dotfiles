# herdr-nav

Navigate [herdr](https://herdr.dev) panes and Neovim splits as if they were
one app. `Ctrl+h/j/k/l` moves between Neovim splits while you're in Neovim,
and falls through to move between herdr panes when Neovim hits an edge — and
the same keys move between herdr panes everywhere else.

Ported from [`vim-herdr-navigation`](https://github.com/paulbkim-dev/vim-herdr-navigation).

## How it works

Two cooperating sides:

- **herdr side** (`navigate.sh`): a herdr keybind binds `Ctrl+h/j/k/l` to a
  plugin action. On each press the action checks the focused pane's foreground
  process via `herdr pane process-info`. If it's Vim/Neovim it forwards the key
  into that pane with `herdr pane send-keys`; otherwise it moves herdr's focus
  with `herdr pane focus --direction`.
- **editor side** (`~/.config/nvim/after/plugin/herdr-nav.lua`): maps the same
  keys to `wincmd h/j/k/l`. If the window didn't change (Vim is at an edge),
  it calls `herdr pane focus --direction` to cross into the neighbouring herdr
  pane, or falls back to `TmuxNavigate*` if running inside tmux.

## Requirements

- herdr `>= 0.7.0`
- `jq` (used by `navigate.sh` to detect Vim; without it the keys still move
  herdr panes, just without Vim awareness)

## Install

### 1. Link the plugin in herdr

```bash
herdr plugin link ~/work/dotfiles/herdr-nav
herdr plugin action list --plugin herdr-nav
```

### 2. Bind the keys in herdr

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "ctrl+h"
type = "plugin_action"
command = "herdr-nav.left"
description = "navigate left (herdr/nvim)"

[[keys.command]]
key = "ctrl+j"
type = "plugin_action"
command = "herdr-nav.down"
description = "navigate down (herdr/nvim)"

[[keys.command]]
key = "ctrl+k"
type = "plugin_action"
command = "herdr-nav.up"
description = "navigate up (herdr/nvim)"

[[keys.command]]
key = "ctrl+l"
type = "plugin_action"
command = "herdr-nav.right"
description = "navigate right (herdr/nvim)"
```

Reload herdr's config (`prefix+shift+r`) or restart.

### 3. Neovim side

The editor file lives at `~/.config/nvim/after/plugin/herdr-nav.lua`. It only
activates when `$HERDR_PANE_ID` is set (i.e. inside a herdr pane), so it
co-exists peacefully with `vim-tmux-navigator` for tmux sessions.

## Notes & tradeoffs

- **`Ctrl+l` / `Ctrl+k` in shells.** Binding these globally shadows readline's
  `Ctrl+L` (clear screen) and `Ctrl+K` (kill line) inside non-Vim panes. This
  is the same tradeoff as `vim-tmux-navigator`. If you want them back, bind
  clear to something else or pick `alt+h/j/k/l` for navigation instead.
- **`Ctrl+H` vs Backspace.** `Ctrl+H` and Backspace share a byte (`0x08`)
  unless the kitty keyboard protocol is active. Neovim ≥ 0.10 enables it
  automatically in herdr panes, keeping `<C-h>` distinct.
- The editor mappings are for normal and visual modes only. Insert mode retains
  its own defaults (`<C-h>` brackets jump, `<C-j>` newline, etc.).
