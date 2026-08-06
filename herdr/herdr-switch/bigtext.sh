#!/usr/bin/env bash
#
# herdr-switch — popup banner shown briefly after prefix+0 toggles.
#
# Prints the focused space name and its path as plain text, then exits after
# a short delay so the popup closes itself. Opened with --no-focus by
# toggle.sh: the popup never steals the cursor, so typing during the banner
# is not swallowed and the cursor stays in the target space's pane.

set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"

ws="$(printf '%s' "$("$herdr" workspace list 2>/dev/null)" \
  | jq -r '.result.workspaces[] | select(.focused == true) | {id: .workspace_id, label: .label} | @json' \
  | head -1 || true)"
ws_id="$(printf '%s' "$ws" | jq -r '.id // empty' 2>/dev/null || true)"
label="$(printf '%s' "$ws" | jq -r '.label // empty' 2>/dev/null || true)"
label="${label:-?}"

cwd="$(printf '%s' "$("$herdr" pane list --workspace "$ws_id" 2>/dev/null)" \
  | jq -r '.result.panes[0].cwd // empty' 2>/dev/null || true)"
cwd="${cwd:-?}"

printf '\x1b[1;32m▶ %s\x1b[0m\n' "$label"
printf '\x1b[90m  %s\x1b[0m\n' "$cwd"
sleep 1.2
exit 0
