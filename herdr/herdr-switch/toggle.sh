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

out="$("$herdr" workspace focus "$target" 2>&1)" || {
  # Target no longer exists: forget it, keep the current record.
  mkdir -p "$state_dir"
  tmp="$state_file.tmp.$$"
  jq -n --arg cur "$current" '{current: $cur, previous: null}' > "$tmp"
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
mkdir -p "$state_dir"
tmp="$state_file.tmp.$$"
jq -n --arg cur "$target" --arg prev "$current" \
  '{current: $cur, previous: ($prev | if . == "" then null else . end)}' > "$tmp"
mv "$tmp" "$state_file"
exit 0
