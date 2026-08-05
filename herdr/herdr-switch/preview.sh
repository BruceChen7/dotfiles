#!/usr/bin/env bash
#
# herdr-switch — fzf preview renderer. Receives the selected TSV line as $1
# (see picker.sh for the field layout) and prints a small detail block.

set -euo pipefail

line="${1:-}"
[ -n "$line" ] || exit 0

kind="$(printf '%s' "$line" | cut -f2)"
target="$(printf '%s' "$line" | cut -f3)"
status="$(printf '%s' "$line" | cut -f4)"
ws="$(printf '%s' "$line" | cut -f5)"
cwd="$(printf '%s' "$line" | cut -f6)"
title="$(printf '%s' "$line" | cut -f7)"
name="$(printf '%s' "$line" | cut -f8)"

if [ "$kind" = "agent" ]; then
  printf '\033[1m%s\033[0m\n' "$name"
  printf '\n'
  printf '状态:   %s\n' "$status"
  printf 'space:  %s\n' "$ws"
  printf 'cwd:    %s\n' "$cwd"
  printf '终端:   %s\n' "$title"
  printf 'pane:   %s\n' "$target"
else
  printf '\033[1m%s\033[0m\n' "$name"
  printf '\n'
  printf 'id:     %s\n' "$target"
  printf 'panes:  %s\n' "$title"
  printf '状态:   %s\n' "$status"
fi
