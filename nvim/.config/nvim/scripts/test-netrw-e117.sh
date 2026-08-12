#!/usr/bin/env bash
# Regression test: `nvim .` must not emit E117 (Unknown function: netrw#LocalBrowseCheck)
#
# Root cause (2025-08-12): init.lua required "plugins" (lazy.nvim setup) before
# "buildin", so lazy's rtp scan sourced $VIMRUNTIME/plugin/netrwPlugin.vim while
# g:loaded_netrw was still unset. netrwPlugin registered a VimEnter autocmd that
# calls netrw#LocalBrowseCheck(); the later `g:loaded_netrw = 1` then blocked the
# autoload file, so opening a directory (`nvim .`) failed with E117.
set -u

LOG=$(mktemp)
cleanup() { rm -f "$LOG"; }
trap cleanup EXIT

# `-c "autocmd VimEnter * qa!"` makes headless exit right after VimEnter fires,
# while still letting every VimEnter autocmd (and its errors) run first.
nvim --headless . -c "autocmd VimEnter * qa!" </dev/null >"$LOG" 2>&1

if grep -q "E117" "$LOG"; then
  echo "FAIL: E117 emitted on 'nvim .':"
  cat "$LOG"
  exit 1
fi

echo "PASS: no E117 on 'nvim .'"
