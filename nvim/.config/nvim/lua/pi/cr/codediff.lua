-- pi.cr.codediff: thin adapter over codediff.nvim internals (accepted coupling).
--
-- Opens the codediff explorer for the CR scope (diffArgs -> session config),
-- overlays the comment keymaps (c/dc/e/q), renders the Comments dock panel and
-- inline cards, and keeps the exit flow semantics (q ends the review).
--
-- Pure decision logic lives in pi.cr.map; this module is the imperative shell.

local M = {}

local map = require "pi.cr.map"
local panel = require "pi.cr.panel"
local comments = require "pi.cr.comments"

local NS_CARDS = vim.api.nvim_create_namespace "pi-cr-cards"

--- Card highlight groups, linked to gruvbox-material's semantic palette when
--- available (the CR review forces that theme); fallback to its hex values.
---@type table<string, {theme: string, fallback: string}>
local TYPE_HL_SPEC = {
  PiCRCommentFix = { theme = "Red", fallback = "#ea6962" },
  PiCRCommentQuestion = { theme = "Yellow", fallback = "#d8a657" },
  PiCRCommentNote = { theme = "Green", fallback = "#a9b665" },
}

---@type table<string, string>
local TYPE_HL = {
  fix = "PiCRCommentFix",
  question = "PiCRCommentQuestion",
  note = "PiCRCommentNote",
}

--- Define the card highlight groups. Call after the colorscheme is active so
--- the theme groups exist to link to.
function M.setup_highlights()
  for name, spec in pairs(TYPE_HL_SPEC) do
    if vim.fn.hlexists(spec.theme) == 1 then
      vim.api.nvim_set_hl(0, name, { link = spec.theme })
    else
      vim.api.nvim_set_hl(0, name, { fg = spec.fallback })
    end
  end
end

local state = {
  app = nil,
  git_root = nil,
  tabpage = nil,
  installed = false,
  last_anchor = nil, -- {file, line} of the last diff cursor anchor (panel c)
  gitsigns_disabled_buffers = {},
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Pi CR" })
end

local function session_of()
  if not state.tabpage or not vim.api.nvim_tabpage_is_valid(state.tabpage) then
    return nil
  end
  return require("codediff.ui.lifecycle").get_session(state.tabpage)
end

--- Buffer shown in the modified (right) window RIGHT NOW. Do NOT trust
--- session.modified_bufnr here: codediff's async view.update may replace or
--- reuse panes, leaving session buffers stale relative to the window.
---@return number|nil
local function modified_buf()
  local lifecycle = require "codediff.ui.lifecycle"
  local _, mod_win = lifecycle.get_windows(state.tabpage)
  if mod_win and vim.api.nvim_win_is_valid(mod_win) then
    return vim.api.nvim_win_get_buf(mod_win)
  end
  return nil
end

---@return number|nil
local function original_buf()
  local lifecycle = require "codediff.ui.lifecycle"
  local orig_win = lifecycle.get_windows(state.tabpage)
  if orig_win and vim.api.nvim_win_is_valid(orig_win) then
    return vim.api.nvim_win_get_buf(orig_win)
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Anchor resolution: cursor position in a codediff buffer -> (file, line)
-- ---------------------------------------------------------------------------

--- Repo-relative file for a view buffer, or nil.
--- Real file buffers carry the absolute path; revision buffers carry a
--- codediff:// URL (see map.parse_codediff_url). Inline scratch buffers have a
--- synthetic name and fall back to the session's current modified ref.
---@param buf number
---@return string|nil
local function file_for_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  if name:sub(1, 12) == "codediff:///" then
    local parsed = map.parse_codediff_url(name)
    return parsed and parsed.filepath or nil
  end
  local root = state.git_root
  if root and name:sub(1, #root + 1) == root .. "/" then
    return name:sub(#root + 2)
  end
  return nil
end

--- The file the session's view currently displays, "" when nothing is shown
--- yet. Deleted files render as a single original-side pane with an empty
--- modified ref, so the shown file is the original side in that case.
---@param session table|nil
---@return string
local function shown_file(session)
  if not session then
    return ""
  end
  local modified = session.modified and session.modified.relative or ""
  if modified ~= "" then
    return modified
  end
  return session.original and session.original.relative or ""
end

--- Whether the session's view shows the selected file on either side.
--- The modified side carries the selection for normal/added/untracked files;
--- deleted files show only the original side (their modified ref is empty),
--- and the VirtualFileLoaded hook passes that empty ref as its target.
---@param session table|nil
---@param target string
---@return boolean
local function view_matches(session, target)
  if not session then
    return false
  end
  local modified = session.modified and session.modified.relative
  local original = session.original and session.original.relative
  return modified == target or original == target
end

--- Context window read from the modified buffer around the anchor.
---@param buf number modified buffer
---@param line number 1-based
---@return CrCommentContext
local function context_at(buf, line)
  local window = 6
  local start = math.max(1, line - window)
  local lines = vim.api.nvim_buf_get_lines(buf, start - 1, line + window, false)
  local context = map.build_context(lines, line - start + 1, 10)
  context.start_line = start + context.start_line - 1
  context.end_line = start + context.end_line - 1
  context.anchor_line = line
  return context
end

--- Resolve the comment context at the current cursor in the modified pane.
--- Visual range optional (first/last buffer lines).
---@param first number|nil
---@param last number|nil
---@return {file: string, line: number, end_line: number, snippet: string, context: CrCommentContext}|nil
function M.anchor_at(first, last)
  local session = session_of()
  if not session then
    return nil
  end
  local buf = vim.api.nvim_get_current_buf()
  local inline = session.layout == "inline"
  local is_modified = buf == modified_buf() or (inline and buf == session.result_bufnr)
  if not is_modified then
    if buf == original_buf() then
      notify "注释仅可添加在右侧（新版本）窗格"
    end
    return nil
  end
  local file = file_for_buf(buf) or (session.modified and session.modified.relative) or nil
  if not file or file == "" then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local end_line = line
  if first then
    if last and last < first then
      first, last = last, first
    end
    line = first
    end_line = last or first
  end
  state.last_anchor = { file = file, line = end_line }
  local context = context_at(buf, line)
  return {
    file = file,
    line = line,
    end_line = end_line,
    snippet = table.concat(context.lines, "\n"),
    context = context,
  }
end

-- ---------------------------------------------------------------------------
-- Hunk navigation (]c/[c) — 单 owner 方案
-- 劫持 codediff 原生 navigation，让它自带 EOF 修复；pi 不再另设 ]c 映射，
-- 彻底消除与 gitsigns / lifecycle 的抢占 race
-- ---------------------------------------------------------------------------

local function do_clamped_nav(orig_nav)
  if state.tabpage ~= vim.api.nvim_get_current_tabpage() then
    return orig_nav()
  end
  local session = session_of()
  if not session then
    return orig_nav()
  end
  if not session.stored_diff_result then
    vim.notify("diff 计算中，请稍后再按 ]c/[c", vim.log.levels.INFO)
    return false
  end
  local win = vim.api.nvim_get_current_win()
  local before = vim.api.nvim_win_get_cursor(win)[1]
  local ok = orig_nav()
  if not ok then
    return false
  end
  local cur = vim.api.nvim_get_current_win()
  if cur ~= win or not vim.api.nvim_win_is_valid(cur) then
    return true -- 已跳文件/窗口，不需修复
  end
  local line = vim.api.nvim_win_get_cursor(cur)[1]
  if line ~= before then
    return true
  end
  local side = "modified"
  if session.layout ~= "inline" and vim.api.nvim_get_current_buf() == original_buf() then
    side = "original"
  end
  local changes = session.stored_diff_result and session.stored_diff_result.changes or {}
  local target = map.hunk_repair_target(changes, side, vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(cur)))
  if target then
    pcall(vim.api.nvim_win_set_cursor, cur, { target, 0 })
    vim.cmd "normal! zz"
  end
  return ok
end

local function patch_codediff_navigation()
  local ok, navi = pcall(require, "codediff.ui.view.navigation")
  if not ok or navi._pi_patched then
    return
  end
  local orig_next, orig_prev = navi.next_hunk, navi.prev_hunk
  navi.next_hunk = function()
    return do_clamped_nav(orig_next)
  end
  navi.prev_hunk = function()
    return do_clamped_nav(orig_prev)
  end
  navi._pi_patched = true
  -- 已有会话的映射闭包仍指向旧函数，需重设
  local s = session_of()
  if s then
    local ok_life, lifecycle = pcall(require, "codediff.ui.lifecycle")
    if ok_life then
      local ob, mb = lifecycle.get_buffers(state.tabpage)
      if ob and mb then
        -- 让 codediff 重建 view 映射（会用到已 patch 的 navi）
        local ok_view, view_keymaps = pcall(require, "codediff.ui.view.keymaps")
        if ok_view then
          pcall(view_keymaps.setup_all_keymaps, state.tabpage, ob, mb, s.mode == "explorer")
        end
      end
    end
  end
end

-- 保持兼容：旧 clamped_hunk_nav 供外部调用，内部转调 do_clamped_nav
local function clamped_hunk_nav(nav)
  return do_clamped_nav(nav)
end

-- ---------------------------------------------------------------------------
-- Comment actions (view keymaps)
-- ---------------------------------------------------------------------------

function M.comment_at_cursor(visual)
  local first, last
  if visual then
    first = vim.fn.line "v"
    last = vim.fn.line "."
  end
  local ctx = M.anchor_at(first, last)
  if ctx then
    comments.add(ctx)
  end
end

function M.delete_at_cursor()
  local session = session_of()
  if not session then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if buf ~= modified_buf() and buf ~= session.result_bufnr then
    notify "注释删除仅可在右侧（新版本）窗格操作"
    return
  end
  local file = file_for_buf(buf) or (session.modified and session.modified.relative) or nil
  if not file or file == "" then
    return
  end
  comments.delete_at(file, vim.api.nvim_win_get_cursor(0)[1])
end

function M.delete_comment_by_id(id)
  comments.delete_by_id(id)
end

function M.new_comment()
  local anchor = state.last_anchor
  if not anchor then
    notify "先在 diff 窗格定位要注释的行（c）"
    return
  end
  local buf = modified_buf()
  local context = buf and context_at(buf, anchor.line)
    or { lines = {}, start_line = anchor.line, anchor_line = anchor.line }
  comments.add {
    file = anchor.file,
    line = anchor.line,
    end_line = anchor.line,
    snippet = table.concat(context.lines, "\n"),
    context = context,
  }
end

function M.open_real_file_at_cursor()
  local ctx = M.anchor_at()
  if not ctx then
    return
  end
  local abs = state.git_root and (state.git_root .. "/" .. ctx.file) or ctx.file
  vim.cmd("tabnew " .. vim.fn.fnameescape(abs))
  vim.b.pi_cr_review_file = true
  pcall(vim.api.nvim_win_set_cursor, 0, { ctx.line, 0 })
  vim.keymap.set("n", "q", function()
    vim.cmd "tabclose"
  end, { buffer = 0, nowait = true })
end

-- ---------------------------------------------------------------------------
-- Inline cards (virt_lines on the modified pane for the current file)
-- ---------------------------------------------------------------------------

---@return string|nil repo-relative path of the file currently shown
local function current_file()
  local session = session_of()
  if not session or not session.modified then
    return nil
  end
  return session.modified.relative
end

function M.render_cards()
  local session = session_of()
  local buf = modified_buf()
  if not session or not buf then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, NS_CARDS, 0, -1)
  local file = current_file()
  if not file or file == "" then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(buf)
  for _, comment in ipairs(comments.comments) do
    if comment.file == file and comment.line >= 1 and comment.line <= line_count then
      local label = comments.type_labels[comment.type] or "NOTE"
      local body = comment.comment:gsub("\n", " / ")
      local hl = TYPE_HL[comment.type] or "PiCRCommentNote"
      vim.api.nvim_buf_set_extmark(buf, NS_CARDS, comment.line - 1, 0, {
        virt_lines = {
          { { string.format("▍[%s] %s", label, body), hl } },
          { { "  ⏎ 面板跳转 · d 删除", "Comment" } },
        },
      })
    end
  end
end

-- ---------------------------------------------------------------------------
-- Panel actions
-- ---------------------------------------------------------------------------

---@param id number
function M.jump_to_comment(id)
  local target
  for _, comment in ipairs(comments.comments) do
    if comment.id == id then
      target = comment
      break
    end
  end
  if not target then
    return
  end
  local lifecycle = require "codediff.ui.lifecycle"
  local explorer = lifecycle.get_panel_view(state.tabpage)
  if not explorer or not explorer.tree then
    notify("explorer 不可用", vim.log.levels.WARN)
    return
  end

  local function find_node(nodes, path)
    for _, node in ipairs(nodes) do
      local data = node.data
      if data and data.path == path and (data.type == nil or data.type == "file") then
        return node
      end
      if #node._children > 0 then
        local hit = find_node(node._children, path)
        if hit then
          return hit
        end
      end
    end
    return nil
  end

  local node = find_node(explorer.tree:get_nodes(), target.file)
  if not node then
    notify("注释目标文件不在当前 diff 中", vim.log.levels.WARN)
    return
  end

  -- Skip re-selecting when the target file is already displayed: reloading
  -- the same file races the async load; just position the cursor.
  local session = session_of()
  local already_shown = session and session.modified and session.modified.relative == target.file

  if not already_shown then
    -- Expand collapsed ancestors so the node is rendered and reachable.
    local chain = {}
    local parent = explorer.tree._nodes_by_id[node._parent_id]
    while parent do
      chain[#chain + 1] = parent
      parent = explorer.tree._nodes_by_id[parent._parent_id]
    end
    for i = #chain, 1, -1 do
      if chain[i]:is_expanded() == false then
        chain[i]:expand()
      end
    end
    explorer.tree:render()

    for line, n in pairs(explorer.tree._line_to_node) do
      if n == node then
        pcall(vim.api.nvim_win_set_cursor, explorer.winid, { line, 0 })
        break
      end
    end
    if explorer.on_file_select then
      explorer.on_file_select(node.data)
    end
  end

  -- After the file loads, move the diff cursor to the comment line. The load
  -- is async (event loop must spin), so poll with a retry budget instead of
  -- a single schedule tick. Deleted files render as a single original-side
  -- pane (their modified side is a scratch that never grows), so the landing
  -- side comes from map.jump_landing; without that the wait burned its full
  -- budget on the empty modified side and the cursor never moved.
  --
  -- Non-blocking: use vim.defer_fn so the UI stays responsive while the
  -- virtual buffer fills. The old blocking vim.wait loop froze the editor
  -- for up to 3s per jump.
  local function jump_tick(attempts, checked_buf, checked_lines, stable_ticks)
    if attempts >= 60 then
      M.render_cards()
      return
    end
    local s = session_of()
    if s and view_matches(s, target.file) then
      local view = {
        single_side = s.single_side,
        modified_lines = s.modified_bufnr and vim.api.nvim_buf_line_count(s.modified_bufnr) or 0,
        original_lines = s.original_bufnr and vim.api.nvim_buf_line_count(s.original_bufnr) or 0,
      }
      local landing = map.jump_landing(view, target.line, stable_ticks or 0)
      if landing.status == "ready" then
        local orig_win, mod_win = lifecycle.get_windows(state.tabpage)
        local win = landing.side == "original" and orig_win or mod_win
        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_win_set_cursor(win, { target.line, 0 })
          vim.cmd "normal! zz"
        end
        M.render_cards()
        return
      end
      if landing.status == "hopeless" then
        M.render_cards()
        return
      end
      local buf = landing.side == "original" and s.original_bufnr or s.modified_bufnr
      local lines = buf and vim.api.nvim_buf_line_count(buf) or 0
      if buf == checked_buf and lines == checked_lines then
        stable_ticks = (stable_ticks or 0) + 1
      else
        stable_ticks = 0
        checked_buf, checked_lines = buf, lines
      end
      vim.defer_fn(function()
        jump_tick(attempts + 1, checked_buf, checked_lines, stable_ticks)
      end, 50)
      return
    end
    vim.defer_fn(function()
      jump_tick(attempts + 1, checked_buf, checked_lines, stable_ticks)
    end, 50)
  end
  jump_tick(0, nil, nil, 0)
end

function M.redraw_all()
  panel.refresh()
  M.render_cards()
end

-- ---------------------------------------------------------------------------
-- Help overlay (replaces codediff's own ? which cannot list our keymaps)
-- ---------------------------------------------------------------------------

--- codediff view keys, read live from its config so reconfigurations show up.
---@type {names: string[], desc: string}[]
local CODEDIFF_HELP = {
  { names = { "next_hunk", "prev_hunk" }, desc = "next / prev hunk" },
  { names = { "next_file", "prev_file" }, desc = "next / prev file" },
  { names = { "toggle_layout" }, desc = "toggle inline / side-by-side" },
  { names = { "toggle_stage" }, desc = "stage / unstage current file" },
  { names = { "stage_hunk", "unstage_hunk" }, desc = "stage / unstage hunk" },
  { names = { "diff_get", "diff_put" }, desc = "get / put change" },
  { names = { "open_in_prev_tab" }, desc = "open real file in previous tab" },
}

local PI_VIEW_HELP = {
  { "c", "comment on line (visual: range)" },
  { "dc", "delete comment on line" },
  { "e", "open real file at line (q to return)" },
  { "<leader>cd", "toggle comments dock" },
  { "<C-h> / <C-l>", "focus prev / next area (explorer · diff · dock)" },
  { "q", "exit review (menu when comments exist)" },
}

local PI_POPUP_HELP = {
  { "<Tab> / <S-Tab>", "cycle comment type (NOTE / FIX / QUESTION)" },
  { "<C-t>", "insert template text" },
  { "<CR> / <Esc>", "save / cancel" },
}

local PI_PANEL_HELP = {
  { "j / k", "move selection" },
  { "<CR>", "jump to comment (syncs explorer + card)" },
  { "d", "delete selected comment" },
  { "za", "fold / unfold group" },
  { "c", "new comment (anchored at diff cursor line)" },
  { "q", "exit review" },
}

--- Build the combined help lines.
---@return string[]
function M.help_lines()
  local keymaps = {}
  local ok = pcall(function()
    keymaps = require("codediff.config").options.keymaps or {}
  end)
  local km = ok and keymaps.view or {}

  local lines = { "Pi CR review keymaps" }
  local function key(name)
    local v = km[name]
    if type(v) == "string" then
      return v
    end
    if type(v) == "table" then
      local flat = {}
      for _, k in ipairs(v) do
        if type(k) == "string" then
          flat[#flat + 1] = k
        end
      end
      return #flat > 0 and table.concat(flat, " / ") or nil
    end
    return nil
  end

  local function add_section(title, rows)
    lines[#lines + 1] = ""
    lines[#lines + 1] = title
    for _, row in ipairs(rows) do
      local keys, desc = row[1], row[2]
      if keys then
        lines[#lines + 1] = string.format("  %-16s %s", keys, desc)
      end
    end
  end

  local codediff_rows = {}
  for _, entry in ipairs(CODEDIFF_HELP) do
    local keys = {}
    for _, name in ipairs(entry.names) do
      local k = key(name)
      if k then
        keys[#keys + 1] = k
      end
    end
    if #keys > 0 then
      codediff_rows[#codediff_rows + 1] = { table.concat(keys, " / "), entry.desc }
    end
  end
  add_section("Diff view (codediff)", codediff_rows)
  add_section("Comments (Pi CR)", PI_VIEW_HELP)
  add_section("Comment popup (after c)", PI_POPUP_HELP)
  add_section("Comments panel (right dock)", PI_PANEL_HELP)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Common: :qa submit + quit · :qa! discard + quit"
  return lines
end

--- Floating help window.
function M.show_help()
  local lines = M.help_lines()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local width = 56
  local height = math.min(#lines + 1, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(1, math.floor(vim.o.lines * 0.15)),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    zindex = 120,
    title = " Pi CR help ",
    title_pos = "center",
  })
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", close, { buffer = buf, nowait = true })
end

-- ---------------------------------------------------------------------------
-- Focus navigation (C-h/j/k/l across explorer / diff panes / comments dock)
-- ---------------------------------------------------------------------------

-- Move focus between CR windows: explorer, original, modified, dock.
-- delta 1 = next (C-l/C-j), -1 = prev (C-h/C-k), wraps. C-h from the
-- modified pane lands on the original pane (the compared-to file).
-- Overrides the global TmuxNavigate keys inside the CR tab.
function M.focus_area(delta)
  local lifecycle = require "codediff.ui.lifecycle"
  local wins = {}
  local explorer = lifecycle.get_panel_view(state.tabpage)
  local ew = explorer and explorer.split and explorer.split.winid
  if ew and vim.api.nvim_win_is_valid(ew) then
    wins[#wins + 1] = ew
  end
  local orig_win, mod_win = lifecycle.get_windows(state.tabpage)
  if orig_win and vim.api.nvim_win_is_valid(orig_win) then
    wins[#wins + 1] = orig_win
  end
  if mod_win and vim.api.nvim_win_is_valid(mod_win) then
    wins[#wins + 1] = mod_win
  end
  local dw = panel._state and panel._state.win
  if dw and vim.api.nvim_win_is_valid(dw) then
    wins[#wins + 1] = dw
  end
  if #wins == 0 then
    return
  end
  local current = vim.api.nvim_get_current_win()
  local index = 1
  for i, win in ipairs(wins) do
    if win == current then
      index = i
      break
    end
  end
  local next_index = ((index - 1 + delta) % #wins) + 1
  vim.api.nvim_set_current_win(wins[next_index])
end

-- ---------------------------------------------------------------------------
-- Exit flow (q keeps "end the review" semantics)
-- ---------------------------------------------------------------------------

local EXIT_MENU = {
  "1. 回传 Pi（发送注释并结束 review）",
  "2. 仅退出（不发送注释）",
  "3. 取消",
}

--- Generic numbered menu float (ported from the old ui.lua).
---@param items string[]
---@param on_select fun(index: number)
local function show_menu(items, on_select)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, items)
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(2, math.floor(vim.o.lines * 0.35)),
    col = math.max(2, math.floor(vim.o.columns * 0.25)),
    width = math.min(56, vim.o.columns - 4),
    height = math.min(#items + 1, vim.o.lines - 4),
    style = "minimal",
    border = "rounded",
    zindex = 130,
    title = " Pi CR review ",
    title_pos = "center",
  })

  local cursor = 1
  local function set_cursor()
    vim.api.nvim_win_set_cursor(win, { cursor, 0 })
  end
  local function close_menu()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  local function select(index)
    close_menu()
    on_select(index)
  end

  vim.keymap.set("n", "j", function()
    cursor = math.min(cursor + 1, #items)
    set_cursor()
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "k", function()
    cursor = math.max(cursor - 1, 1)
    set_cursor()
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", function()
    select(cursor)
  end, { buffer = buf, nowait = true })
  for index = 1, math.min(#items, 9) do
    vim.keymap.set("n", tostring(index), function()
      select(index)
    end, { buffer = buf, nowait = true })
  end
  vim.keymap.set("n", "<Esc>", function()
    select(#items)
  end, { buffer = buf, nowait = true })
end

function M.exit_flow()
  if #comments.comments > 0 then
    show_menu(EXIT_MENU, function(choice)
      if choice == 3 then
        return
      end
      if choice == 2 then
        comments.clear_all()
      end
      state.app.finish(true)
    end)
  else
    state.app.finish(true)
  end
end

-- ---------------------------------------------------------------------------
-- Keymaps + hooks (session-scoped; die with the buffers on CodeDiffClose)
-- ---------------------------------------------------------------------------

local function buf_set_keymap(buf, mode, lhs, rhs, desc, extra_opts)
  local tabpage = state.tabpage
  if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
    local ok_life, lifecycle = pcall(require, "codediff.ui.lifecycle")
    if ok_life and lifecycle.get_session(tabpage) then
      local opts =
        vim.tbl_extend("force", { desc = desc, noremap = true, silent = true, nowait = true }, extra_opts or {})
      pcall(lifecycle.set_buf_keymap, tabpage, buf, mode, lhs, rhs, opts, { priority = 100 })
    end
  end
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = buf, desc = desc }, extra_opts or {}))
end

local function mark_gitsigns_disabled(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if not state.gitsigns_disabled_buffers[buf] then
    state.gitsigns_disabled_buffers[buf] = {
      had_disable = vim.b[buf].pi_cr_disable_gitsigns ~= nil,
      disable = vim.b[buf].pi_cr_disable_gitsigns,
      had_enabled = vim.b[buf].gitsigns_enabled ~= nil,
      enabled = vim.b[buf].gitsigns_enabled,
    }
  end
  vim.b[buf].pi_cr_disable_gitsigns = true
  vim.b[buf].gitsigns_enabled = false
  return true
end

local function restore_gitsigns_disabled_buffers()
  local disabled = state.gitsigns_disabled_buffers
  state.gitsigns_disabled_buffers = {}
  for buf, previous in pairs(disabled) do
    if vim.api.nvim_buf_is_valid(buf) then
      if previous.had_disable then
        vim.b[buf].pi_cr_disable_gitsigns = previous.disable
      else
        vim.b[buf].pi_cr_disable_gitsigns = nil
      end
      if previous.had_enabled then
        vim.b[buf].gitsigns_enabled = previous.enabled
      else
        vim.b[buf].gitsigns_enabled = nil
      end
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and not name:match "^codediff:///" and previous.enabled ~= false then
        pcall(require("gitsigns.attach").attach, buf, nil, "PiCRClose")
      end
    end
  end
end

local function disable_gitsigns(buf)
  if not mark_gitsigns_disabled(buf) then
    return
  end
  pcall(function()
    require("gitsigns").detach(buf)
  end)
end

local function install_view_keymaps(original_buf, modified_buf)
  for _, buf in ipairs(map.keymap_buffers(original_buf, modified_buf)) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      disable_gitsigns(buf)
      buf_set_keymap(buf, "n", "c", function()
        M.comment_at_cursor(false)
      end, "Pi CR comment")
      buf_set_keymap(buf, "x", "c", function()
        M.comment_at_cursor(true)
      end, "Pi CR comment (range)")
      buf_set_keymap(buf, "n", "dc", M.delete_at_cursor, "Pi CR delete comment")
      buf_set_keymap(buf, "n", "e", M.open_real_file_at_cursor, "Pi CR open real file")
      -- ]c/[c 已由 patch_codediff_navigation 劫持 codediff 原生 navigation 实现单 owner，不再此处设映射
      buf_set_keymap(buf, "n", "q", M.exit_flow, "Pi CR exit review")
      buf_set_keymap(buf, "n", "?", M.show_help, "Pi CR help")
      buf_set_keymap(buf, "n", "<leader>cd", function()
        panel.toggle()
      end, "Pi CR toggle comments dock")
      for _, k in ipairs { { "<C-h>", -1 }, { "<C-k>", -1 }, { "<C-l>", 1 }, { "<C-j>", 1 } } do
        buf_set_keymap(buf, "n", k[1], function()
          M.focus_area(k[2])
        end, "Pi CR focus " .. (k[2] < 0 and "prev area" or "next area"))
      end
    end
  end
end

--- Re-apply keymaps to the session's current buffers. The view buffers are
--- REPLACED when a file is selected/loaded (explorer placeholders swap in real
--- or virtual buffers), so keymaps bound once at open() are lost; re-binding
--- keeps c/dc/e/q alive across file switches and layout toggles.
local function reinstall_keymaps()
  local session = session_of()
  if not session then
    return
  end
  install_view_keymaps(original_buf(), modified_buf())
  local ok_life, lifecycle = pcall(require, "codediff.ui.lifecycle")
  local explorer = ok_life and lifecycle.get_panel_view(state.tabpage) or nil
  if explorer and explorer.split and explorer.split.bufnr and vim.api.nvim_buf_is_valid(explorer.split.bufnr) then
    local buf = explorer.split.bufnr
    buf_set_keymap(buf, "n", "c", function()
      notify "注释需在右侧 diff 窗格定位行后按 c"
    end, "Pi CR comment (hint)")
    -- q must end the review from every pane, not just the diff windows.
    buf_set_keymap(buf, "n", "q", M.exit_flow, "Pi CR exit review")
    buf_set_keymap(buf, "n", "?", M.show_help, "Pi CR help")
    buf_set_keymap(buf, "n", "<leader>cd", function()
      panel.toggle()
    end, "Pi CR toggle comments dock")
    for _, k in ipairs { { "<C-h>", -1 }, { "<C-k>", -1 }, { "<C-l>", 1 }, { "<C-j>", 1 } } do
      buf_set_keymap(buf, "n", k[1], function()
        M.focus_area(k[2])
      end, "Pi CR focus " .. (k[2] < 0 and "prev area" or "next area"))
    end
  end
end

--- Wait (with retries) until the session's view shows the target file, then
--- (re)install the keymaps. codediff's view.update is async and swaps the
--- placeholder panes for real/virtual buffers; installing before the swap
--- lands would bind buffers that are about to be wiped, and a "c already
--- present" check on the previous file's buffer would stop the retry
--- prematurely. The file-identity check is the reliable completion signal:
--- after the swap, session.modified.relative == target — except for deleted
--- files, whose modified side is an empty ref (single original-side pane), so
--- the original side must be checked too.
---
--- Chains are self-cancelling: each selection bumps the sequence, so a chain
--- superseded by a newer selection stops once the view moves to a file that
--- is not its target (that keymap install is the newer chain's job). Without
--- this, chains for deleted files could never complete early and would burn
--- their full retry budget (60 x 50ms) per selection, and rapid Tab
--- navigation would pile up concurrent chains. Polling uses vim.defer_fn
--- (non-blocking) so the UI stays responsive.
local reinstall_seq = 0
local function reinstall_keymaps_until_file(target, tries)
  tries = tries or 60
  reinstall_seq = reinstall_seq + 1
  local seq = reinstall_seq
  local start_shown
  local function tick(remaining)
    if remaining <= 0 or seq ~= reinstall_seq then
      return
    end
    local session = session_of()
    if view_matches(session, target) then
      reinstall_keymaps()
      return
    end
    local shown = shown_file(session)
    if start_shown == nil then
      start_shown = shown -- view still on the previous file: keep waiting
    end
    if shown ~= start_shown then
      return -- view moved to a file that is not our target: superseded
    end
    vim.defer_fn(function()
      tick(remaining - 1)
    end, 50)
  end
  tick(tries)
end

local function setup_hooks()
  if state.installed then
    return
  end
  state.installed = true
  patch_codediff_navigation()
  local augroup = vim.api.nvim_create_augroup("PiCRCodediff", { clear = true })
  -- 源头禁用 gitsigns：codediff 虚拟缓冲 + diff 窗真实文件缓冲
  vim.api.nvim_create_autocmd({ "BufAdd", "BufReadPre" }, {
    group = augroup,
    callback = function(args)
      local buf = args.buf
      local name = vim.api.nvim_buf_get_name(buf)
      if name:sub(1, 12) == "codediff:///" then
        mark_gitsigns_disabled(buf)
        pcall(require("gitsigns").detach, buf)
        return
      end
      local s = session_of()
      if s and s.git_root and name ~= "" and name:sub(1, #s.git_root + 1) == s.git_root .. "/" then
        -- 真实文件且在 review 的 git 仓库内，可能是 diff 窗缓冲，预先禁用避免抢占 ]c
        mark_gitsigns_disabled(buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "CodeDiffFileSelect",
    callback = function(args)
      local target = args.data and args.data.path
      vim.schedule(function()
        -- pcall: during the placeholder->real buffer swap render_cards can hit
        -- a freshly wiped buffer; the keymap reinstall must still run.
        pcall(M.render_cards)
        -- 首按无映射：view.update 的 nvim_win_set_buf 后立即重装（不走 50ms 轮询），
        -- 否则用户在 async 完成前首按 ]c 必无反应，切 Tab 后 BufEnter 才补上
        pcall(reinstall_keymaps)
        pcall(reinstall_keymaps_until_file, target)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "CodeDiffVirtualFileLoaded",
    callback = function()
      vim.schedule(function()
        pcall(M.render_cards)
        -- Session may still be settling when this fires; wait for the file
        -- identity to match, then install.
        local target = nil
        local s = session_of()
        if s and s.modified then
          target = s.modified.relative
        end
        pcall(reinstall_keymaps_until_file, target)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "CodeDiffClose",
    callback = function()
      vim.schedule(function()
        comments.close_ui "codediff-close"
        panel.close()
        restore_gitsigns_disabled_buffers()
      end)
    end,
  })
  -- BufEnter does NOT fire for codediff's nvim_win_set_buf swaps, but it does
  -- fire on real user navigation (e.g. <C-w>w into the diff pane); keep it as
  -- an interaction-level fallback. The reliable re-install path is the two
  -- User events above.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      reinstall_keymaps()
    end,
  })
  -- nvim_win_set_buf 触发 BufWinEnter（而非 BufEnter），首文件在 view.update 异步完成前
  -- 首按 ]c 时映射还未通过轮询设上，靠此立即补上
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = function(args)
      local buf = args.buf
      local s = session_of()
      if not s then
        return
      end
      local ok_life, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok_life then
        return
      end
      local orig_win, mod_win = lifecycle.get_windows(state.tabpage)
      local cur_ob = orig_win and vim.api.nvim_win_is_valid(orig_win) and vim.api.nvim_win_get_buf(orig_win) or nil
      local cur_mb = mod_win and vim.api.nvim_win_is_valid(mod_win) and vim.api.nvim_win_get_buf(mod_win) or nil
      if buf == cur_ob or buf == cur_mb then
        disable_gitsigns(buf)
        reinstall_keymaps()
      end
    end,
  })
  -- gitsigns 后于 pi 附加时会抢占 ]c；对 diff 窗的两个缓冲直接禁用
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "GitsignsAttach",
    callback = function(args)
      local buf = args.data and args.data.buf or args.buf
      if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local s = session_of()
      if not s then
        return
      end
      local ok_life, lifecycle = pcall(require, "codediff.ui.lifecycle")
      local obuf, mbuf = nil, nil
      if ok_life then
        obuf, mbuf = lifecycle.get_buffers(state.tabpage)
      end
      if buf == obuf or buf == mbuf then
        disable_gitsigns(buf)
      end
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Fallback: raw git diff in a plain buffer when codediff is unavailable
-- ---------------------------------------------------------------------------

local function fallback()
  local app = state.app
  local args = { "git", "diff", "--no-color", "--no-ext-diff" }
  if app and app.config and app.config.diffArgs then
    vim.list_extend(args, app.config.diffArgs)
  end
  local output = vim.fn.system(args)
  local lines = vim.split(output, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "diff"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_set_current_buf(buf)
  vim.keymap.set("n", "q", M.exit_flow, { buffer = buf, desc = "Pi CR exit review" })
  vim.keymap.set("n", "c", function()
    notify("降级模式不支持注释", vim.log.levels.WARN)
  end, { buffer = buf, desc = "Pi CR comment (unavailable)" })
  notify("codediff 不可用，展示原始 diff（降级模式，无注释）", vim.log.levels.WARN)
end

-- ---------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------

---@param app table shared review state ({config, finish, context_lines})
function M.open(app)
  state.app = app

  local ok_scope, scope = pcall(map.scope_to_session, app.config and app.config.diffArgs)
  if not ok_scope or not scope.ok then
    notify("不支持的 diff scope：" .. tostring(scope and scope.reason or "?"), vim.log.levels.ERROR)
    fallback()
    return
  end

  local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if not root or root == "" then
    notify("不在 git 仓库中", vim.log.levels.ERROR)
    vim.cmd "qa"
    return
  end
  state.git_root = root
  patch_codediff_navigation()

  local ok, codediff = pcall(require, "codediff.ui.view")
  if not ok then
    notify("codediff.nvim 未安装或加载失败", vim.log.levels.ERROR)
    fallback()
    return
  end
  local view = codediff
  local git = require "codediff.core.git"

  local function fail(err)
    notify("CR 会话创建失败：" .. tostring(err), vim.log.levels.ERROR)
    fallback()
  end

  local function create_view(status_result, original_rev, modified_rev)
    local has_changes = (status_result.unstaged and #status_result.unstaged > 0)
      or (status_result.staged and #status_result.staged > 0)
      or (status_result.conflicts and #status_result.conflicts > 0)
    if not has_changes then
      notify "No changes to review"
      app.finish(true)
      return
    end
    local result = view.create(
      map.explorer_session_config(status_result, {
        git_root = root,
        original_revision = original_rev,
        modified_revision = modified_rev,
      }),
      ""
    )
    M.setup_highlights()
    state.tabpage = vim.api.nvim_get_current_tabpage()
    setup_hooks()
    install_view_keymaps(result.original_buf, result.modified_buf)
    panel.register {
      jump = M.jump_to_comment,
      delete = M.delete_comment_by_id,
      new_comment = M.new_comment,
      exit = M.exit_flow,
      help = M.show_help,
      parent_win = select(2, require("codediff.ui.lifecycle").get_windows(state.tabpage)),
    }
    panel.sync()
    M.render_cards()
    notify("Opened CR review for " .. tostring(app.config.label or ""))
  end

  local scope_kind = scope.scope.kind
  if scope_kind == "status" then
    local okc, err = pcall(git.get_status_with_line_stats, root, function(err_status, status_result)
      if err_status then
        fail(err_status)
        return
      end
      vim.schedule(function()
        create_view(status_result, nil, nil)
      end)
    end)
    if not okc then
      fail(err)
    end
  elseif scope_kind == "staged" then
    git.resolve_revision("HEAD", root, function(err_rev, hash)
      if err_rev then
        fail(err_rev)
        return
      end
      git.get_diff_staged(hash, root, function(err_status, status_result)
        if err_status then
          fail(err_status)
          return
        end
        vim.schedule(function()
          create_view(status_result, hash, ":0")
        end)
      end)
    end)
  else -- range
    git.get_merge_base(scope.scope.base, scope.scope.target, root, function(err_base, merge_base)
      if err_base then
        fail(err_base)
        return
      end
      git.resolve_revision(scope.scope.base, root, function(err_base_rev, hash_base)
        if err_base_rev then
          fail(err_base_rev)
          return
        end
        git.resolve_revision(scope.scope.target, root, function(err_target_rev, hash_target)
          if err_target_rev then
            fail(err_target_rev)
            return
          end
          git.get_diff_revisions_with_line_stats(hash_base, hash_target, root, function(err_status, status_result)
            if err_status then
              fail(err_status)
              return
            end
            vim.schedule(function()
              create_view(status_result, hash_base, hash_target)
            end)
          end)
        end)
      end)
    end)
  end
end

M._state = state -- smoke hook
M._reinstall = reinstall_keymaps -- smoke hook
M._shown_file = shown_file -- smoke hook
M._view_matches = view_matches -- smoke hook

return M
