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

--- Snippet window read from the modified buffer around the anchor (plain file
--- lines, no diff prefixes; cap 10).
---@param buf number modified buffer
---@param line number 1-based
---@return string
local function snippet_at(buf, line)
  local window = 6
  local start = math.max(1, line - window)
  local lines = vim.api.nvim_buf_get_lines(buf, start - 1, line + window, false)
  return map.build_snippet(lines, line - start + 1, 10)
end

--- Resolve the comment context at the current cursor in the modified pane.
--- Visual range optional (first/last buffer lines).
---@param first number|nil
---@param last number|nil
---@return {file: string, line: number, end_line: number, snippet: string}|nil
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
  return { file = file, line = line, end_line = end_line, snippet = snippet_at(buf, line) }
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
  local snippet = buf and snippet_at(buf, anchor.line) or ""
  comments.add {
    file = anchor.file,
    line = anchor.line,
    end_line = anchor.line,
    snippet = snippet,
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
  local explorer = lifecycle.get_explorer(state.tabpage)
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
  -- is async (event loop must spin), so wait with a retry budget instead of
  -- a single schedule tick.
  vim.schedule(function()
    local lifecycle = require "codediff.ui.lifecycle"
    local attempts = 0
    while attempts < 60 do
      local s = session_of()
      local buf = s and s.modified_bufnr
      if buf and vim.api.nvim_buf_line_count(buf) >= target.line then
        break
      end
      attempts = attempts + 1
      vim.wait(50, function()
        return false
      end)
    end
    local s = session_of()
    local buf = s and s.modified_bufnr
    local _, mod_win = lifecycle.get_windows(state.tabpage)
    if buf and mod_win and vim.api.nvim_win_is_valid(mod_win) and vim.api.nvim_buf_line_count(buf) >= target.line then
      vim.api.nvim_set_current_win(mod_win)
      vim.api.nvim_win_set_cursor(mod_win, { target.line, 0 })
      vim.cmd "normal! zz"
    end
    M.render_cards()
  end)
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
  local explorer = lifecycle.get_explorer(state.tabpage)
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

local function install_view_keymaps(original_buf, modified_buf)
  for _, buf in ipairs { original_buf, modified_buf } do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.keymap.set("n", "c", function()
        M.comment_at_cursor(false)
      end, { buffer = buf, desc = "Pi CR comment" })
      vim.keymap.set("x", "c", function()
        M.comment_at_cursor(true)
      end, { buffer = buf, desc = "Pi CR comment (range)" })
      vim.keymap.set("n", "dc", M.delete_at_cursor, { buffer = buf, desc = "Pi CR delete comment" })
      vim.keymap.set("n", "e", M.open_real_file_at_cursor, { buffer = buf, desc = "Pi CR open real file" })
      vim.keymap.set("n", "q", M.exit_flow, { buffer = buf, desc = "Pi CR exit review" })
      vim.keymap.set("n", "?", M.show_help, { buffer = buf, desc = "Pi CR help" })
      vim.keymap.set("n", "<leader>cd", function()
        panel.toggle()
      end, { buffer = buf, desc = "Pi CR toggle comments dock" })
      for _, k in ipairs { { "<C-h>", -1 }, { "<C-k>", -1 }, { "<C-l>", 1 }, { "<C-j>", 1 } } do
        vim.keymap.set("n", k[1], function()
          M.focus_area(k[2])
        end, { buffer = buf, desc = "Pi CR focus " .. (k[2] < 0 and "prev area" or "next area") })
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
  local lifecycle = require "codediff.ui.lifecycle"
  local explorer = lifecycle.get_explorer(state.tabpage)
  if explorer and explorer.split and explorer.split.bufnr and vim.api.nvim_buf_is_valid(explorer.split.bufnr) then
    local buf = explorer.split.bufnr
    vim.keymap.set("n", "c", function()
      notify "注释需在右侧 diff 窗格定位行后按 c"
    end, { buffer = buf, desc = "Pi CR comment (hint)" })
    -- q must end the review from every pane, not just the diff windows.
    vim.keymap.set("n", "q", M.exit_flow, { buffer = buf, desc = "Pi CR exit review" })
    vim.keymap.set("n", "?", M.show_help, { buffer = buf, desc = "Pi CR help" })
    vim.keymap.set("n", "<leader>cd", function()
      panel.toggle()
    end, { buffer = buf, desc = "Pi CR toggle comments dock" })
    for _, k in ipairs { { "<C-h>", -1 }, { "<C-k>", -1 }, { "<C-l>", 1 }, { "<C-j>", 1 } } do
      vim.keymap.set("n", k[1], function()
        M.focus_area(k[2])
      end, { buffer = buf, desc = "Pi CR focus " .. (k[2] < 0 and "prev area" or "next area") })
    end
  end
end

--- Wait (with retries) until the session's modified file matches the target
--- the user selected, then (re)install the keymaps. codediff's view.update is
--- async and swaps the placeholder panes for real/virtual buffers; installing
--- before the swap lands would bind buffers that are about to be wiped, and a
--- "c already present" check on the previous file's buffer would stop the
--- retry prematurely. The file-identity check is the reliable completion
--- signal: after the swap, session.modified.relative == target.
local function reinstall_keymaps_until_file(target, tries)
  tries = tries or 60
  vim.schedule(function()
    local session = session_of()
    local current = session and session.modified and session.modified.relative
    if current == target then
      reinstall_keymaps()
      return
    end
    if tries <= 0 then
      return
    end
    vim.wait(50, function()
      return false
    end)
    reinstall_keymaps_until_file(target, tries - 1)
  end)
end

local function setup_hooks()
  if state.installed then
    return
  end
  state.installed = true
  local augroup = vim.api.nvim_create_augroup("PiCRCodediff", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "CodeDiffFileSelect",
    callback = function(args)
      local target = args.data and args.data.path
      vim.schedule(function()
        -- pcall: during the placeholder->real buffer swap render_cards can hit
        -- a freshly wiped buffer; the keymap reinstall must still run.
        pcall(M.render_cards)
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
      vim.schedule(panel.close)
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

  local ok, codediff = pcall(require, "codediff.ui.view")
  if not ok then
    notify("codediff.nvim 未安装或加载失败", vim.log.levels.ERROR)
    fallback()
    return
  end
  local view = codediff
  local git = require "codediff.core.git"
  local path = require "codediff.core.path"

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
    local result = view.create({
      mode = "explorer",
      git_root = root,
      original = path.empty(),
      modified = path.empty(),
      original_revision = original_rev,
      modified_revision = modified_rev,
      exit_on_close = true,
      explorer_data = {
        status_result = status_result,
        focus_file = nil,
        pathspec = nil,
      },
    }, "")
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

return M
