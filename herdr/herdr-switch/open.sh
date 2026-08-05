#!/usr/bin/env bash
#
# herdr-switch — action entry point (bound to prefix+f).
#
# Opens the picker popup pane declared in herdr-plugin.toml. The popup is a
# session-modal floating terminal; it closes when picker.sh exits.

set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
plugin_id="${HERDR_PLUGIN_ID:-herdr-switch}"

exec "$herdr" plugin pane open --plugin "$plugin_id" --entrypoint picker
