#!/usr/bin/env bash
#
# herdr-switch — the picker (runs inside a popup pane, see herdr-plugin.toml).
#
# Pulls `herdr agent list` + `herdr workspace list`, merges them into one
# TSV stream, and hands it to fzf:
#   enter      → agent.focus <pane_id> / workspace.focus <workspace_id>
#   alt+enter  → agent attach <pane_id> --takeover
#   ctrl+x     → close: agent → pane close; space → workspace close.
#                Confirmation is only required when the target is dangerous:
#                agent working/blocked, space with running agents, or the
#                current (focused) space. Idle targets close directly.
#
# After a close the popup stays open and the list refreshes (keeping the
# query) so several workspaces can be cleaned up in a row; esc exits.
#
# Line format (tab-separated):
#   1  display   — ANSI-colored text shown in the list (fzf searches only this)
#   2  kind      — agent | space
#   3  target    — pane_id (agent) | workspace_id (space)
#   4  status    — display status: agent_status / "当前" / "-"
#   5  ws        — workspace label
#   6  cwd       — full cwd ("" for space rows)
#   7  title     — terminal title / "<n> panes"
#   8  name      — agent label / workspace label
#   9  raw       — raw status for logic: agent_status / "current" / "-"
#   10 running   — count of running (working|blocked) agents: agent 1|0, space N
#
# Failure modes (as designed):
#   a. herdr API fails          → print error, wait for a key, then exit
#   b. no agents                → workspace rows still shown and searchable
#   c. fzf cancelled (esc/ctrl-c) → exit silently
#   d. action fails after list  → print error, wait for a key, stay in the list

set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
  # Fatal: popup closes when this script exits, so keep it open long enough to read.
  printf '\033[31m%s\033[0m\n' "$1" >&2
  printf '\033[90m按任意键关闭…\033[0m' >&2
  read -r -n 1 -s || true
  exit 1
}

warn() {
  # Non-fatal: show an error, wait for a key, then return (stay in the loop).
  printf '\033[31m%s\033[0m\n' "$1" >&2
  printf '\033[90m按任意键继续…\033[0m' >&2
  read -r -n 1 -s || true
  printf '\n' >&2
}

agents_json=""
ws_json=""
cur_ws=""

fetch_data() {
  agents_json="$("$herdr" agent list 2>/dev/null)" || fail "herdr agent list 失败(herdr 在运行吗?)"
  ws_json="$("$herdr" workspace list 2>/dev/null)" || fail "herdr workspace list 失败"

  printf '%s' "$agents_json" | jq -e '.result.agents' >/dev/null 2>&1 \
    || fail "agent list 返回了无法解析的数据"
  printf '%s' "$ws_json" | jq -e '.result.workspaces' >/dev/null 2>&1 \
    || fail "workspace list 返回了无法解析的数据"

  cur_ws="$(printf '%s' "$ws_json" | jq -r '.result.workspaces[] | select(.focused == true) | .label' | head -1)"
  cur_ws="${cur_ws:-?}"
}

build_lines() {
  local wsmap agents_map
  wsmap="$(printf '%s' "$ws_json" \
    | jq -c '[.result.workspaces[] | {key: .workspace_id, value: {label: .label, pane_count: .pane_count}}] | from_entries')"
  agents_map="$(printf '%s' "$agents_json" \
    | jq -c '[.result.agents[] | {ws: .workspace_id, status: .agent_status}]')"

  # Agent rows: focused first, then original order.
  printf '%s' "$agents_json" | jq -r --argjson ws "$wsmap" '
    .result.agents | sort_by(.focused | not) | .[] |
    [
      ((.agent_status) as $s |
        (if $s == "working" then "\u001b[33m●\u001b[0m"
         elif $s == "blocked" then "\u001b[31m●\u001b[0m"
         elif $s == "done" then "\u001b[34m●\u001b[0m"
         else "\u001b[90m●\u001b[0m" end))
        + " agent  " + (.name // .agent) + " @ " + ($ws[.workspace_id].label // .workspace_id)
        + "  " + (.cwd
            | sub("^/Users/ming.chen/work/"; "~/work/")
            | sub("^/Users/ming.chen/"; "~/"))
        + (if .focused then "  ◀ 聚焦" else "" end),
      "agent",
      .pane_id,
      .agent_status + (if .focused then " (聚焦)" else "" end),
      ($ws[.workspace_id].label // .workspace_id),
      .cwd,
      (.terminal_title_stripped // ""),
      (.name // .agent),
      .agent_status,
      (if .agent_status == "working" or .agent_status == "blocked" then "1" else "0" end)
    ] | @tsv
  ' > "$lines_file"

  # Workspace rows: focused first, then original order. Spaces with running
  # agents are marked with a yellow icon; the running count goes to field 10.
  printf '%s' "$ws_json" | jq -r --argjson agents "$agents_map" '
    .result.workspaces | sort_by(.focused | not) | .[] |
    (.workspace_id as $wid |
      ([ $agents[] | select(.ws == $wid and (.status == "working" or .status == "blocked")) ] | length) as $running |
      [
        (if $running > 0 then "\u001b[33m▣\u001b[0m" else "\u001b[35m▣\u001b[0m" end)
          + " space  " + .label + (if .focused then "  ◀ 当前" else "" end),
        "space",
        .workspace_id,
        (if .focused then "当前" else "-" end),
        .label,
        "",
        (.pane_count | tostring) + " panes",
        .label,
        (if .focused then "current" else "-" end),
        ($running | tostring)
      ] | @tsv
    )
  ' >> "$lines_file"
}

# close flow for ctrl+x. Returns 0 when the action finished (success or
# cancelled) so the loop refreshes; non-fatal errors warn and return 0 too.
do_close() {
  local kind="$1" target="$2" name="$3" raw="$4" running="$5"
  local need_confirm=0 msg="" ans out

  if [ "$kind" = "agent" ]; then
    if [ "$raw" = "working" ] || [ "$raw" = "blocked" ]; then
      need_confirm=1
      msg="close agent $name? (状态: $raw)"
    fi
  else
    if [ "$raw" = "current" ]; then
      need_confirm=1
      msg="close space $name? (当前 space)"
    elif [ "${running:-0}" -gt 0 ] 2>/dev/null; then
      need_confirm=1
      msg="close space $name? ($running 个 agent 运行中)"
    fi
  fi

  if [ "$need_confirm" = "1" ]; then
    printf '\033[33m%s [y/N] \033[0m' "$msg"
    read -r -n 1 -s ans || true
    printf '\n'
    case "$ans" in
      y|Y) ;;
      *)
        printf '\033[90m已取消\033[0m\n'
        return 0
        ;;
    esac
  fi

  if [ "$kind" = "agent" ]; then
    out="$("$herdr" pane close "$target" 2>&1)" \
      || { warn "pane close 失败: $name\n$(printf '%s' "$out" | head -5)"; return 0; }
    printf '\033[90mclosed agent %s\033[0m\n' "$name"
  else
    out="$("$herdr" workspace close "$target" 2>&1)" \
      || { warn "workspace close 失败: $name\n$(printf '%s' "$out" | head -5)"; return 0; }
    printf '\033[90mclosed space %s\033[0m\n' "$name"
  fi
  return 0
}

# ---------- main loop ----------
lines_file="$(mktemp)"
trap 'rm -f "$lines_file"' EXIT

query=""

while true; do
  # Re-pull data every iteration so closes are reflected in the list.
  fetch_data
  build_lines

  set +e
  out="$(cat "$lines_file" | fzf \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=1 \
    --header "当前 space: $cur_ws    enter=focus · alt+enter=attach · ctrl+x=close · esc=退出" \
    --preview "bash '$here/preview.sh' {}" \
    --preview-window=right:40% \
    --bind 'alt-enter:accept' \
    --print-query \
    --expect=alt-enter,ctrl-x \
    --query "$query" \
    --no-multi \
    --no-sort \
    --tiebreak=index
  )"
  rc=$?
  set -e

  # c. Cancelled / no match → silent exit.
  if [ "$rc" -ne 0 ]; then
    exit 0
  fi

  # Output layout: query, pressed key ('' for enter), selected line.
  query="$(printf '%s\n' "$out" | sed -n '1p')"
  key="$(printf '%s\n' "$out" | sed -n '2p')"
  line="$(printf '%s\n' "$out" | sed -n '3p')"
  [ -n "$line" ] || continue

  kind="$(printf '%s' "$line" | cut -f2)"
  target="$(printf '%s' "$line" | cut -f3)"
  name="$(printf '%s' "$line" | cut -f8)"
  raw="$(printf '%s' "$line" | cut -f9)"
  running="$(printf '%s' "$line" | cut -f10)"

  case "$key" in
    ctrl-x)
      do_close "$kind" "$target" "$name" "$raw" "$running"
      continue
      ;;
    alt-enter)
      if [ "$kind" != "agent" ]; then
        warn "alt+enter 只能用于 agent(当前选中: space $name)"
        continue
      fi
      out2="$("$herdr" agent attach "$target" --takeover 2>&1)" \
        || { warn "agent attach 失败: $name\n$(printf '%s' "$out2" | head -5)"; continue; }
      break
      ;;
    *)
      # enter → focus
      if [ "$kind" = "agent" ]; then
        out2="$("$herdr" agent focus "$target" 2>&1)" \
          || { warn "agent focus 失败: $name\n$(printf '%s' "$out2" | head -5)"; continue; }
      else
        out2="$("$herdr" workspace focus "$target" 2>&1)" \
          || { warn "workspace focus 失败: $name\n$(printf '%s' "$out2" | head -5)"; continue; }
      fi
      break
      ;;
  esac
done

exit 0
