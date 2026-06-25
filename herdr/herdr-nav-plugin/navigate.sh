#!/usr/bin/env bash
#
# herdr-nav — herdr side
#
# Invoked by herdr keybind as: navigate.sh <left|down|up|right|clear-screen>
#
# Navigation (left/down/up/right):
#   If the focused pane is running Vim/Neovim in the foreground, hand the
#   matching Ctrl chord to that pane so Vim moves between its own splits
#   (and, at a split edge, calls back into herdr to cross the pane boundary).
#   For any other foreground process, move herdr's pane focus directly.
#
# Clear screen (clear-screen):
#   Sends Ctrl+l to the current pane, replacing the readline binding that
#   navigation captures. Mirrors tmux's prefix+k approach.
#
# Requires `jq` for Vim detection. Without it navigation still moves herdr
# panes, just without Vim awareness.

set -euo pipefail

dir="${1:?usage: navigate.sh <left|down|up|right|clear-screen>}"
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_PANE_ID:-}"

case "$dir" in
  left)         key="ctrl+h" ;;
  down)         key="ctrl+j" ;;
  up)           key="ctrl+k" ;;
  right)        key="ctrl+l" ;;
  clear-screen)
    if [ -z "$pane" ]; then
      exit 0
    fi
    exec "$herdr" pane send-keys "$pane" "ctrl+l"
    ;;
  *) echo "navigate.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Foreground process names that mean "Vim is in control of this pane".
# Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff, ...
vim_re='^g?(view|l?n?vim?x?)(diff)?$'

is_vim=0
if [ -n "$pane" ] && command -v jq >/dev/null 2>&1; then
  if "$herdr" pane process-info --current 2>/dev/null \
    | jq -e --arg re "$vim_re" \
        '.result.process_info.foreground_processes[]?.name
         | ascii_downcase
         | select(test($re))' >/dev/null 2>&1; then
    is_vim=1
  fi
fi

if [ "$is_vim" -eq 1 ]; then
  exec "$herdr" pane send-keys "$pane" "$key"
else
  exec "$herdr" pane focus --direction "$dir" --current
fi
