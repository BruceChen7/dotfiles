#!/usr/bin/env bash
# E2E regression for Pi CR hunk navigation ownership:
# first ]c must work even after gitsigns has had time to attach; <Tab>/<S-Tab>
# must not be required to repair the mapping.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/tests/pi_cr/first_hunk_e2e.lua"
python3 - "$script" <<'PY'
import os
import signal
import subprocess
import sys

script = sys.argv[1]
cmd = [
    "nvim",
    "--headless",
    "-u",
    "tests/minimal_init.lua",
    "-c",
    f"luafile {script}",
]
proc = subprocess.Popen(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    preexec_fn=os.setsid,
)
try:
    out, _ = proc.communicate(timeout=10)
    print(out, end="")
    raise SystemExit(proc.returncode or 0)
except subprocess.TimeoutExpired:
    os.killpg(proc.pid, signal.SIGKILL)
    out, _ = proc.communicate()
    print(out, end="")
    print(f"[HARNESS-FAIL] timeout killed nvim pid {proc.pid}")
    raise SystemExit(124)
PY
