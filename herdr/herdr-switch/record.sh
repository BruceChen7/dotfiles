#!/usr/bin/env bash
#
# herdr-switch — workspace.focused event hook.
#
# Maintains a {current, previous} record of the two most recently focused
# spaces in HERDR_PLUGIN_STATE_DIR/prev-space.json. Fires on every focus
# change; same-space pane switches arrive with an unchanged workspace_id and
# are ignored. The record is what prefix+^ (toggle.sh) jumps between.
#
# Atomic write (tmp + mv) keeps concurrent hook invocations safe enough:
# a lost race just means one focus step is not recorded.

set -euo pipefail

state_dir="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugins/state/herdr-switch}"
state_file="$state_dir/prev-space.json"

# HERDR_PLUGIN_EVENT_JSON is the full EventEnvelope serialized:
#   {"event": "workspace.focused", "data": {"type": "workspace_focused", "workspace_id": "..."}}
new="$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-}" | jq -r '.data.workspace_id // .workspace_id // empty' 2>/dev/null || true)"
[ -n "$new" ] || exit 0

old_current="$(jq -r '.current // empty' "$state_file" 2>/dev/null || true)"
# Same workspace (e.g. switching panes inside a space) → not a space change.
[ "$new" = "$old_current" ] && exit 0

mkdir -p "$state_dir"
tmp="$state_file.tmp.$$"
jq -n --arg cur "$new" --arg prev "$old_current" \
  '{current: $cur, previous: ($prev | if . == "" then null else . end)}' > "$tmp"
mv "$tmp" "$state_file"
exit 0
