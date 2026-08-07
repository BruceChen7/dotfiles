#!/usr/bin/env bash
#
# herdr-switch — workspace.focused event hook.
#
# Maintains focus history in HERDR_PLUGIN_STATE_DIR/prev-space.json:
#   current   — the currently focused workspace
#   previous  — the workspace focused just before (prefix+^ toggle target)
#   recent    — recency list, most recent first, capped at 20. This is what
#               orders the prefix+f picker (most recently used at the bottom).
# Fires on every focus change (including API-driven jumps); same-space pane
# switches arrive with an unchanged workspace_id and are ignored.
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

old="$(cat "$state_file" 2>/dev/null || true)"
old_current="$(printf '%s' "$old" | jq -r '.current // empty' 2>/dev/null || true)"
# Same workspace (e.g. switching panes inside a space) → not a space change.
[ "$new" = "$old_current" ] && exit 0

# Old state may predate the recent field, be missing, or be corrupted —
# degrade to an empty list in all of those cases.
old_recent="$(printf '%s' "$old" | jq -c '(.recent // []) as $r | if ($r | type) == "array" then $r else [] end' 2>/dev/null || true)"
old_recent="${old_recent:-[]}"

# New recency: the focused workspace first, then the rest minus it, capped.
recent="$(printf '%s' "$old_recent" | jq -c --arg n "$new" '[$n] + (map(select(. != $n))) | .[0:20]')"

mkdir -p "$state_dir"
tmp="$state_file.tmp.$$"
jq -n --arg cur "$new" --arg prev "$old_current" --argjson recent "$recent" \
  '{current: $cur, previous: ($prev | if . == "" then null else . end), recent: $recent}' > "$tmp"
mv "$tmp" "$state_file"
exit 0
