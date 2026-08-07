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
# Ordering: rows are sorted by workspace recency (tracked by record.sh's
# workspace.focused hook) — least recently used at the top, MOST RECENTLY
# USED AT THE BOTTOM. On open the cursor is parked on the bottom row
# (fzf load:last), so the last-used space is one Enter away; ↑ walks back
# through history. After a close the cursor parks above the deleted row
# (load:pos) instead.
#
# Line format (tab-separated):
#   1  display   — ANSI-colored text shown in the list (fzf searches only this)
#   2  kind      — agent | space
#   3  target    — pane_id (agent) | workspace_id (space)
#   4  status    — display status: agent_status / "当前" / "-"
#   5  ws        — workspace label
#   6  cwd       — cwd with $HOME redacted to ~ ("" for space rows)
#   7  title     — terminal title (also redacted) / "<n> panes"
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
tabs_json=""
cur_ws=""
cur_tab=""

# Recency list (most recent first) maintained by record.sh via the
# workspace.focused event hook. Rows are sorted so that the most recently
# used workspace sits at the BOTTOM of the list (and fzf's load:last parks
# the cursor there on open). Missing/corrupt state → empty list; rows for
# workspaces that were never recorded fall back to the original order at
# the top of the list.
state_dir="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugins/state/herdr-switch}"
recent="$(jq -c '(.recent // []) as $r | if ($r | type) == "array" then $r else [] end' "$state_dir/prev-space.json" 2>/dev/null || true)"
recent="${recent:-[]}"

fetch_data() {
  agents_json="$("$herdr" agent list 2>/dev/null)" || fail "herdr agent list 失败(herdr 在运行吗?)"
  ws_json="$("$herdr" workspace list 2>/dev/null)" || fail "herdr workspace list 失败"
  tabs_json="$("$herdr" tab list 2>/dev/null)" || fail "herdr tab list 失败"

  printf '%s' "$agents_json" | jq -e '.result.agents' >/dev/null 2>&1 \
    || fail "agent list 返回了无法解析的数据"
  printf '%s' "$ws_json" | jq -e '.result.workspaces' >/dev/null 2>&1 \
    || fail "workspace list 返回了无法解析的数据"
  printf '%s' "$tabs_json" | jq -e '.result.tabs' >/dev/null 2>&1 \
    || fail "tab list 返回了无法解析的数据"

  cur_ws="$(printf '%s' "$ws_json" | jq -r '.result.workspaces[] | select(.focused == true) | .label' | head -1)"
  cur_ws="${cur_ws:-?}"
  cur_tab="$(printf '%s' "$tabs_json" | jq -r '
    .result.tabs[] | select(.focused == true)
    | if (.label | test("^[0-9]+$")) then "t\(.label)" else .label end
  ' | head -1)"
  cur_tab="${cur_tab:-?}"
}

build_lines() {
  local wsmap agents_map tabmap
  wsmap="$(printf '%s' "$ws_json" \
    | jq -c '[.result.workspaces[] | {key: .workspace_id, value: {label: .label, pane_count: .pane_count}}] | from_entries')"
  agents_map="$(printf '%s' "$agents_json" \
    | jq -c '[.result.agents[] | {ws: .workspace_id, status: .agent_status}]')"
  tabmap="$(printf '%s' "$tabs_json" | jq -c '
    [.result.tabs[] | {key: .tab_id,
                       value: (if (.label | test("^[0-9]+$")) then "t\(.label)" else .label end)}]
    | from_entries
  ')"

  # Redact the home directory (derived from $HOME, not a hardcoded user) so
  # the username never appears in the list or the preview pane.
  home_re="$(printf '%s' "$HOME" | sed 's/[][(){}.*+?^$|\\]/\\&/g')"

  # Agent rows: sorted by recency — most recently used workspace (and the
  # focused one) at the BOTTOM, least recent / never-recorded at the top
  # (original order preserved by jq's stable sort). Tab label (t<N> for
  # unnamed tabs, custom name otherwise) shown after the workspace label.
  printf '%s' "$agents_json" | jq -r --argjson ws "$wsmap" --argjson tabs "$tabmap" --argjson recent "$recent" --arg home "$HOME" --arg home_re "$home_re" '
    def redact:
      if . == $home then "~"
      elif startswith($home + "/") then "~/" + .[($home | length) + 1:]
      else . end;
    def redact_anywhere: gsub($home_re + "(?=/|$)"; "~");
    def recency_rank: (.workspace_id) as $wid | if .focused then 1 else -((($recent | index($wid)) // 999999)) end;
    .result.agents | sort_by(recency_rank) | .[] |
    ((.cwd | redact) as $cwd_disp |
     ((.terminal_title_stripped // "" | redact_anywhere) as $title_disp |
      [
        ((.agent_status) as $s |
          (if $s == "working" then "\u001b[33m●\u001b[0m"
           elif $s == "blocked" then "\u001b[31m●\u001b[0m"
           elif $s == "done" then "\u001b[34m●\u001b[0m"
           else "\u001b[90m●\u001b[0m" end))
          + " agent  " + (.name // .agent) + " @ " + ($ws[.workspace_id].label // .workspace_id)
          + " · " + ($tabs[.tab_id] // "")
          + "  " + $cwd_disp
          + (if .focused then "  ◀ 聚焦" else "" end),
        "agent",
        .pane_id,
        .agent_status + (if .focused then " (聚焦)" else "" end),
        ($ws[.workspace_id].label // .workspace_id),
        $cwd_disp,
        $title_disp,
        (.name // .agent),
        .agent_status,
        (if .agent_status == "working" or .agent_status == "blocked" then "1" else "0" end)
      ] | @tsv
     ))
  ' > "$lines_file"

  # Workspace rows: sorted by recency like the agents — most recently used
  # (and the current space) at the BOTTOM. Spaces with running agents are
  # marked with a yellow icon; the running count goes to field 10.
  printf '%s' "$ws_json" | jq -r --argjson agents "$agents_map" --argjson recent "$recent" '
    def recency_rank: (.workspace_id) as $wid | if .focused then 1 else -((($recent | index($wid)) // 999999)) end;
    .result.workspaces | sort_by(recency_rank) | .[] |
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

# close flow for ctrl+x. Return codes tell the loop where to park the cursor:
#   0 = closed (list shrank by one)
#   1 = cancelled by the user (list unchanged)
#   2 = failed after warn (list unchanged)
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
        return 1
        ;;
    esac
  fi

  if [ "$kind" = "agent" ]; then
    out="$("$herdr" pane close "$target" 2>&1)" \
      || { warn "pane close 失败: $name\n$(printf '%s' "$out" | head -5)"; return 2; }
    printf '\033[90mclosed agent %s\033[0m\n' "$name"
  else
    out="$("$herdr" workspace close "$target" 2>&1)" \
      || { warn "workspace close 失败: $name\n$(printf '%s' "$out" | head -5)"; return 2; }
    printf '\033[90mclosed space %s\033[0m\n' "$name"
  fi
  return 0
}

# ---------- main loop ----------
lines_file="$(mktemp)"
trap 'rm -f "$lines_file"' EXIT

query=""
next_index=""   # 1-based row to park the cursor on after a close refresh

while true; do
  # Re-pull data every iteration so closes are reflected in the list.
  fetch_data
  build_lines

  # Park the cursor after a close: fzf starts on the first row, so use the
  # start/load events to jump straight to the row above the deleted one.
  # On a fresh open, start:last + load:last park the cursor on the most
  # recently used workspace at the bottom of the list (shell-history style:
  # newest last). --sync makes start fire after the input is complete, so
  # start:last is reliable; load:last is kept as a second shot.
  # (start:down+... does not work — cursor movement in the start event is
  # reset; pos(N)/last are the working forms.)
  binds="alt-enter:accept"
  if [ -n "$next_index" ]; then
    binds="$binds,start:pos($next_index),load:pos($next_index)"
  else
    binds="$binds,start:last,load:last"
  fi

  # Debug aid (always-on, tiny): dump the exact list + recency this popup
  # built (with timestamp, pid and binds) so ordering/cursor problems can
  # be diagnosed from /tmp without guessing.
  # `reverse-list` keeps the prompt at the bottom while displaying input
  # rows top-to-bottom, so the last/current row remains at the bottom.
  cp "$lines_file" /tmp/herdr-switch-lines.txt 2>/dev/null || true
  printf '{"ts":"%s","pid":%s,"recent":%s,"binds":"%s"}\n' "$(date +%H:%M:%S)" "$$" "$recent" "$binds" > /tmp/herdr-switch-recent.txt

  set +e
  out="$(cat "$lines_file" | fzf \
    --ansi \
    --layout=reverse-list \
    --sync \
    --delimiter=$'\t' \
    --with-nth=1 \
    --header "当前 space: $cur_ws · 当前 tab: $cur_tab    enter=focus · alt+enter=attach · ctrl+x=close · esc=退出 · 最近使用在底部" \
    --preview "bash '$here/preview.sh' {}" \
    --preview-window=right:40% \
    --bind "$binds" \
    --print-query \
    --expect=alt-enter,ctrl-x \
    --query "$query" \
    --no-multi \
    --no-sort \
    --tiebreak=index
  )"
  rc=$?
  set -e
  next_index=""

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
      # 1-based index of the selected row in the filtered list, using fzf's
      # own --filter so ordering matches the interactive view exactly.
      # (|| true: grep no-match must not kill the script under pipefail.)
      idx="$(cat "$lines_file" \
        | fzf --filter "$query" --with-nth=1 --delimiter=$'\t' --no-sort --ansi 2>/dev/null \
        | grep -n -F -x -- "$line" | head -1 | cut -d: -f1 || true)"
      idx="${idx:-1}"
      do_close "$kind" "$target" "$name" "$raw" "$running" || true
      rc2=$?
      if [ "$rc2" = 0 ]; then
        # Closed: the row above the deleted one (which shrank the list by one).
        next_index=$((idx - 1))
        [ "$next_index" -lt 1 ] && next_index=1
      else
        # Cancelled or failed: list unchanged, keep the cursor on the same row.
        next_index=$idx
      fi
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
