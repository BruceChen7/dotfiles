#!/usr/bin/env bash
#
# herdr-switch — prefix+^ toggle action.
#
# Jumps to the previously focused space (recorded by record.sh) and swaps
# current/previous, so pressing ^ again returns. Mirrors tmux last-window.
#
# Failure modes:
#   - no record yet / previous already closed → silent no-op (the record is
#     dropped when the target no longer exists, so the next ^ is quiet again)
#   - focus API error → drop the stale previous, keep current, stay quiet

set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
state_dir="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugins/state/herdr-switch}"
state_file="$state_dir/prev-space.json"

[ -f "$state_file" ] || exit 0

target="$(jq -r '.previous // empty' "$state_file" 2>/dev/null || true)"
[ -n "$target" ] || exit 0

current="$(jq -r '.current // empty' "$state_file" 2>/dev/null || true)"

# Old state may predate the recent field — degrade to an empty list.
old_recent="$(jq -c '(.recent // []) as $r | if ($r | type) == "array" then $r else [] end' "$state_file" 2>/dev/null || true)"
old_recent="${old_recent:-[]}"

out="$("$herdr" workspace focus "$target" 2>&1)" || {
  # Target no longer exists: forget it, keep the current record and recency.
  mkdir -p "$state_dir"
  tmp="$state_file.tmp.$$"
  jq -n --arg cur "$current" --argjson recent "$old_recent" \
    '{current: $cur, previous: null, recent: $recent}' > "$tmp"
  mv "$tmp" "$state_file"
  exit 0
}

# Toast banner: show which space we just landed on. Uses the TUI toast
# (delivery = "herdr"), the same surface as the built-in "reloaded config"
# notification. Non-modal — typing is never interrupted. Display duration
# is hardcoded per kind in herdr (UpdateInstalled → 3s), not configurable.
# If a toast is already visible the new one is rejected (single slot); that
# is fine for the toggle flow.
label="$("$herdr" workspace get "$target" 2>/dev/null | jq -r '.result.workspace.label // empty' || true)"
[ -n "$label" ] || label="$target"
"$herdr" notification show "→ $label" --body "workspace $target" --sound none >/dev/null 2>&1 || true

# Swap: the jumped-to space becomes current, the old current becomes
# previous (idempotent with what the workspace.focused event hook writes).
# Recency moves the target to the front as well, so a toggle still reads as
# "just used this space".
recent="$(printf '%s' "$old_recent" | jq -c --arg t "$target" '[$t] + (map(select(. != $t))) | .[0:20]')"
mkdir -p "$state_dir"
tmp="$state_file.tmp.$$"
jq -n --arg cur "$target" --arg prev "$current" --argjson recent "$recent" \
  '{current: $cur, previous: ($prev | if . == "" then null else . end), recent: $recent}' > "$tmp"
mv "$tmp" "$state_file"
exit 0
