#!/usr/bin/env bash
# Run pi.cr pure-logic specs (plenary busted) in an isolated env.
# PlenaryBustedDirectory spawns one headless nvim per spec file; the
# minimal_init option makes those subprocesses use tests/minimal_init.lua
# instead of the user's real init.lua.
set -euo pipefail
cd "$(dirname "$0")/.."
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/pi_cr {minimal_init = 'tests/minimal_init.lua'}"
