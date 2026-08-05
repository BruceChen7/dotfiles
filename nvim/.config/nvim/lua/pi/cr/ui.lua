-- pi.cr.ui: review.nvim-style review UI — dedicated tab with floating windows:
-- left sidebar (Files / Comments sections) + right unified diff pane.

local M = {}

local NS = vim.api.nvim_create_namespace "pi-cr-comments"

local ui = {
  app = nil,
  sidebar_buf = nil,
  sidebar_win = nil,
  sidebar_visible = true,
  diff_buf = nil,
  diff_win = nil,
  help_win = nil,
  menu_win = nil,
  focus = "files", -- "files" | "comments" | "diff"
  files_cursor = 1,
  comments_cursor = 1,
  file_rows = {}, -- sidebar bufline -> file index
  comment_rows = {}, -- sidebar bufline -> comment index
  diff_map = {}, -- diff bufline -> {kind, new_line, old_line, hunk}
  hunk_rows = {}, -- diff bufline of each hunk header
}

local EXIT_MENU = {
  "1. 回传 Pi（发送注释并结束 review）",
  "2. 仅退出（保留注释，不发送）",
  "3. 取消",
}

local function notify(message, level)
  local resolved_level = level or vim.log.levels.INFO
  local function do_notify()
    vim.notify(message, resolved_level, { title = "Pi CR" })
  end
  if vim.in_fast_event() then
    vim.schedule(do_notify)
  else
    do_notify()
  end
end

local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  return buf
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function layout()
  local cols = vim.o.columns
  local lines = vim.o.lines
  local height = lines - 2
  if ui.sidebar_visible then
    local sidebar_width = math.min(44, math.floor(cols * 0.32))
    vim.api.nvim_win_set_config(ui.sidebar_win, {
      relative = "editor",
      row = 1,
      col = 1,
      width = sidebar_width,
      height = height,
    })
    vim.api.nvim_win_set_config(ui.diff_win, {
      relative = "editor",
      row = 1,
      col = sidebar_width + 2,
      width = math.max(20, cols - sidebar_width - 3),
      height = height,
    })
  else
    vim.api.nvim_win_set_config(ui.diff_win, {
      relative = "editor",
      row = 1,
      col = 1,
      width = cols - 2,
      height = height,
    })
  end
end

-- ---------------------------------------------------------------------------
-- Sidebar
-- ---------------------------------------------------------------------------

local function comments_header_line()
  return 2 + #ui.app.files + 1
end

local function sidebar_position_cursor()
  if ui.focus == "files" then
    if #ui.app.files > 0 then
      vim.api.nvim_win_set_cursor(ui.sidebar_win, { 1 + ui.files_cursor, 0 })
    end
  elseif ui.focus == "comments" then
    local comments = require "pi.cr.comments"
    if #comments.comments > 0 then
      vim.api.nvim_win_set_cursor(ui.sidebar_win, { comments_header_line() + ui.comments_cursor, 0 })
    end
  end
end

local function truncate(text, width)
  local flat = text:gsub("\n", " / ")
  local shown = vim.fn.strcharpart(flat, 0, width)
  if vim.fn.strchars(flat) > width then
    shown = shown .. "…"
  end
  return shown
end

local function render_sidebar()
  local comments = require "pi.cr.comments"
  local lines = { "Files" }
  ui.file_rows = {}
  for index, file in ipairs(ui.app.files) do
    local mark = index == ui.app.selected and "▸" or " "
    local counts = file.binary and "binary" or string.format("+%d -%d", file.additions, file.deletions)
    lines[#lines + 1] = string.format("%s %s  %s", mark, file.path, counts)
    ui.file_rows[#lines] = index
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Comments"
  ui.comment_rows = {}
  for index, comment in ipairs(comments.comments) do
    local label = comments.type_labels[comment.type] or "NOTE"
    lines[#lines + 1] =
      string.format(" [%s] %s:%d  %s", label, comment.file, comment.line, truncate(comment.comment, 34))
    ui.comment_rows[#lines] = index
  end
  set_lines(ui.sidebar_buf, lines)
  vim.api.nvim_buf_clear_namespace(ui.sidebar_buf, NS, 0, -1)
  vim.api.nvim_buf_set_extmark(ui.sidebar_buf, NS, 0, 0, { hl_group = "Title" })
  vim.api.nvim_buf_set_extmark(ui.sidebar_buf, NS, comments_header_line() - 1, 0, { hl_group = "Title" })
  sidebar_position_cursor()
end

-- ---------------------------------------------------------------------------
-- Diff pane
-- ---------------------------------------------------------------------------

local function file_counts(file)
  if file.binary then
    return "binary"
  end
  return string.format("+%d -%d", file.additions, file.deletions)
end

local function render_diff_comments()
  local comments = require "pi.cr.comments"
  vim.api.nvim_buf_clear_namespace(ui.diff_buf, NS, 0, -1)
  local selected = ui.app.files[ui.app.selected]
  if not selected then
    return
  end
  -- group comments by target bufline
  local per_line = {}
  for _, comment in ipairs(comments.comments) do
    if comment.file == selected.path then
      for bufline, entry in pairs(ui.diff_map) do
        if entry.new_line == comment.line and entry.kind ~= "del" then
          per_line[bufline] = per_line[bufline] or {}
          table.insert(per_line[bufline], comment)
          break
        end
      end
    end
  end
  for bufline, comment_list in pairs(per_line) do
    local virt = {}
    for _, comment in ipairs(comment_list) do
      local label = comments.type_labels[comment.type] or "NOTE"
      table.insert(virt, { { string.format("[%s] %s", label, truncate(comment.comment, 88)), "PiCRComment" } })
    end
    vim.api.nvim_buf_set_extmark(ui.diff_buf, NS, bufline - 1, 0, { virt_lines = virt })
  end
end

local function render_diff()
  local file = ui.app.files[ui.app.selected]
  ui.diff_map = {}
  ui.hunk_rows = {}
  if not file then
    set_lines(ui.diff_buf, { "No changes" })
    return
  end

  local lines = { string.format("── %s (%s) ──", file.path, file_counts(file)) }
  if file.binary then
    lines[#lines + 1] = "Binary file"
  else
    for _, hunk in ipairs(file.hunks) do
      lines[#lines + 1] =
        string.format("@@ -%d,%d +%d,%d @@", hunk.old_start, hunk.old_count, hunk.new_start, hunk.new_count)
      ui.hunk_rows[#ui.hunk_rows + 1] = #lines
      for _, entry in ipairs(hunk.lines) do
        local prefix = entry.kind == "add" and "+" or (entry.kind == "del" and "-" or " ")
        lines[#lines + 1] = prefix .. entry.text
        ui.diff_map[#lines] = {
          kind = entry.kind,
          new_line = entry.new_line,
          old_line = entry.old_line,
          hunk = hunk,
        }
      end
    end
  end
  set_lines(ui.diff_buf, lines)
  render_diff_comments()
end

function M.render_all()
  render_sidebar()
  render_diff()
end

-- ---------------------------------------------------------------------------
-- Context helpers
-- ---------------------------------------------------------------------------

--- Anchor new-side line for a diff pane buffer line (deleted lines anchor to hunk start).
---@param bufline number
---@return number|nil
local function anchor_line(bufline)
  local entry = ui.diff_map[bufline]
  if not entry then
    return nil
  end
  return entry.new_line or (entry.hunk and entry.hunk.new_start)
end

---@param bufline number
---@return {file: string, line: number, end_line: number, snippet: string}|nil
function M.context_at(bufline)
  local file = ui.app.files[ui.app.selected]
  if not file then
    return nil
  end
  local line = anchor_line(bufline)
  if not line then
    return nil
  end
  local diff = require "pi.cr.diff"
  return {
    file = file.path,
    line = line,
    end_line = line,
    snippet = diff.snippet_for_new_line(file, line, ui.app.context_lines),
  }
end

---@param start_line number diff pane buffer line
---@param end_line number diff pane buffer line
---@return {file: string, line: number, end_line: number, snippet: string}|nil
function M.context_range(start_line, end_line)
  local file = ui.app.files[ui.app.selected]
  if not file then
    return nil
  end
  local first = anchor_line(start_line)
  local last = anchor_line(end_line)
  if not first or not last then
    return nil
  end
  if last < first then
    first, last = last, first
  end
  local diff = require "pi.cr.diff"
  return {
    file = file.path,
    line = first,
    end_line = last,
    snippet = diff.snippet_for_new_line(file, first, ui.app.context_lines),
  }
end

-- ---------------------------------------------------------------------------
-- Focus management
-- ---------------------------------------------------------------------------

local function focus(name)
  ui.focus = name
  if name == "diff" then
    vim.api.nvim_set_current_win(ui.diff_win)
  else
    vim.api.nvim_set_current_win(ui.sidebar_win)
    sidebar_position_cursor()
  end
end

local function cycle_focus(offset)
  local order = { "files", "comments", "diff" }
  local index = 1
  for i, name in ipairs(order) do
    if name == ui.focus then
      index = i
      break
    end
  end
  local next_index = ((index - 1 + offset) % #order) + 1
  focus(order[next_index])
end

-- ---------------------------------------------------------------------------
-- Help / menu overlays
-- ---------------------------------------------------------------------------

local HELP_LINES = {
  "Pi CR review keymaps",
  "",
  "Files panel",
  "  j / k          move",
  "  <CR>           load file diff",
  "  <Space>        stage / unstage",
  "  e              open real file",
  "  R              refresh",
  "Comments panel",
  "  <CR>           jump to comment",
  "  d              delete comment",
  "Diff pane",
  "  c              comment on line (visual: range)",
  "  dc             delete comment on line",
  "  ]c / [c        next / prev hunk",
  "  ]f / [f        next / prev file",
  "  { / }          more / less context",
  "  e              open real file at line",
  "Common",
  "  q              close (exit menu when comments exist)",
  "  ?              this help",
  "  <C-n>          toggle sidebar",
  "  <C-h> / <C-l>  focus files / diff",
  "  <Tab> / h / l  cycle panels",
}

local function show_help()
  if ui.help_win and vim.api.nvim_win_is_valid(ui.help_win) then
    vim.api.nvim_win_close(ui.help_win, false)
    return
  end
  local buf = create_buf()
  set_lines(buf, HELP_LINES)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(1, math.floor(vim.o.lines * 0.15)),
    col = math.max(1, math.floor(vim.o.columns * 0.25)),
    width = math.min(64, vim.o.columns - 4),
    height = math.min(#HELP_LINES + 1, vim.o.lines - 4),
    style = "minimal",
    border = "rounded",
    zindex = 120,
    title = " Pi CR help ",
    title_pos = "center",
  })
  ui.help_win = win
  local function close_help()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    ui.help_win = nil
  end
  vim.keymap.set("n", "q", close_help, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_help, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", close_help, { buffer = buf, nowait = true })
end

--- Generic menu overlay. Esc and the last item both cancel.
---@param items string[]
---@param on_select fun(index: number)
local function show_menu(items, on_select)
  local buf = create_buf()
  set_lines(buf, items)
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
  ui.menu_win = win

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
    ui.menu_win = nil
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

-- ---------------------------------------------------------------------------
-- Exit / open-real-file flows
-- ---------------------------------------------------------------------------

---@param choice number 1 = submit to Pi, 2 = exit without sending, 3 = cancel
---@param on_submit fun() called after submit/discard handling (not for cancel)
local function exit_menu(on_submit)
  show_menu(EXIT_MENU, function(choice)
    if choice == 3 then
      return
    end
    local comments = require "pi.cr.comments"
    if choice == 2 then
      comments.clear_all()
    end
    on_submit()
  end)
end

local function close_ui()
  for _, win in ipairs { ui.help_win, ui.menu_win, ui.sidebar_win, ui.diff_win } do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
  end
  ui.help_win = nil
  ui.menu_win = nil
  ui.sidebar_win = nil
  ui.diff_win = nil
  pcall(vim.cmd, "tabclose")
end

--- q / quit flow: exit menu when comments exist, else quit directly.
function M.close(app)
  local comments = require "pi.cr.comments"
  if #comments.comments > 0 then
    exit_menu(function()
      app.finish(true)
    end)
  else
    app.finish(true)
  end
end

--- Open a real file, closing the review UI. Raises the exit menu when comments exist.
---@param path string
---@param line number|nil
function M.open_real_file(app, path, line)
  local comments = require "pi.cr.comments"
  local function do_open()
    close_ui()
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    if line and line > 0 then
      pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
    end
  end
  if #comments.comments > 0 then
    exit_menu(function()
      app.finish(false)
      do_open()
    end)
  else
    do_open()
  end
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

local function select_file(index)
  ui.app.selected = index
  ui.files_cursor = index
  M.render_all()
  focus "diff"
end

local function hunk_move(direction)
  local current = vim.fn.line "."
  local target = nil
  if direction > 0 then
    for _, row in ipairs(ui.hunk_rows) do
      if row > current then
        target = row
        break
      end
    end
  else
    for index = #ui.hunk_rows, 1, -1 do
      if ui.hunk_rows[index] < current then
        target = ui.hunk_rows[index]
        break
      end
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

local function file_move(direction)
  local next_index = ui.app.selected + direction
  if next_index >= 1 and next_index <= #ui.app.files then
    select_file(next_index)
  end
end

local function jump_to_comment(comment)
  for index, file in ipairs(ui.app.files) do
    if file.path == comment.file then
      ui.app.selected = index
      ui.files_cursor = index
      M.render_all()
      for bufline, entry in pairs(ui.diff_map) do
        if entry.new_line == comment.line and entry.kind ~= "del" then
          vim.api.nvim_win_set_cursor(ui.diff_win, { bufline, 0 })
          break
        end
      end
      focus "diff"
      return
    end
  end
  notify("Comment target file no longer in the diff", vim.log.levels.WARN)
end

local function first_change_line(path)
  local diff = require "pi.cr.diff"
  for _, file in ipairs(ui.app.files) do
    if file.path == path then
      for _, hunk in ipairs(file.hunks) do
        for _, entry in ipairs(hunk.lines) do
          if entry.new_line then
            return entry.new_line
          end
        end
        if hunk.new_count > 0 then
          return hunk.new_start
        end
      end
      return 1
    end
  end
  return 1
end

-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------

local function sidebar_move(direction)
  if ui.focus == "files" then
    ui.files_cursor = math.max(1, math.min(ui.files_cursor + direction, #ui.app.files))
    sidebar_position_cursor()
  elseif ui.focus == "comments" then
    local comments = require "pi.cr.comments"
    ui.comments_cursor = math.max(1, math.min(ui.comments_cursor + direction, #comments.comments))
    sidebar_position_cursor()
  end
end

local function sidebar_enter()
  if ui.focus == "files" then
    local index = ui.file_rows[vim.fn.line "."]
    if index then
      select_file(index)
    end
  elseif ui.focus == "comments" then
    local comments = require "pi.cr.comments"
    local index = ui.comment_rows[vim.fn.line "."]
    if index and comments.comments[index] then
      jump_to_comment(comments.comments[index])
    end
  end
end

local function sidebar_delete()
  if ui.focus ~= "comments" then
    return
  end
  local comments = require "pi.cr.comments"
  local index = ui.comment_rows[vim.fn.line "."]
  if index and comments.comments[index] then
    comments.delete_by_id(comments.comments[index].id)
  end
end

local function sidebar_space()
  if ui.focus ~= "files" then
    return
  end
  local index = ui.file_rows[vim.fn.line "."]
  if not index then
    return
  end
  local git = require "pi.cr.git"
  git.toggle(ui.app, ui.app.files[index].path)
end

local function sidebar_open_file()
  if ui.focus ~= "files" then
    return
  end
  local index = ui.file_rows[vim.fn.line "."]
  if index then
    local file = ui.app.files[index]
    M.open_real_file(ui.app, file.path, first_change_line(file.path))
  end
end

local function toggle_sidebar()
  ui.sidebar_visible = not ui.sidebar_visible
  if ui.sidebar_visible then
    ui.sidebar_win = vim.api.nvim_open_win(ui.sidebar_buf, false, {
      relative = "editor",
      row = 1,
      col = 1,
      width = 10,
      height = 1,
    })
    sidebar_position_cursor()
  else
    vim.api.nvim_win_hide(ui.sidebar_win)
  end
  layout()
end

local function diff_comment(visual)
  local comments = require "pi.cr.comments"
  local context
  if visual then
    local first = vim.fn.line "v"
    local last = vim.fn.line "."
    if last < first then
      first, last = last, first
    end
    context = M.context_range(first, last)
  else
    context = M.context_at(vim.fn.line ".")
  end
  if context then
    comments.add(context)
  end
end

local function diff_delete()
  local comments = require "pi.cr.comments"
  local file = ui.app.files[ui.app.selected]
  if not file then
    return
  end
  local line = anchor_line(vim.fn.line ".")
  if line then
    comments.delete_at(file.path, line)
  end
end

local function set_keymaps()
  vim.keymap.set("n", "j", function()
    sidebar_move(1)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "k", function()
    sidebar_move(-1)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "<CR>", sidebar_enter, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "<Space>", sidebar_space, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "d", sidebar_delete, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "e", sidebar_open_file, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "R", function()
    local git = require "pi.cr.git"
    git.refresh(ui.app)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "q", function()
    M.close(ui.app)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "?", show_help, { buffer = ui.sidebar_buf })

  vim.keymap.set("n", "<Tab>", function()
    cycle_focus(1)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "l", function()
    cycle_focus(1)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "h", function()
    cycle_focus(-1)
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "<C-h>", function()
    focus "files"
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "<C-l>", function()
    focus "diff"
  end, { buffer = ui.sidebar_buf })
  vim.keymap.set("n", "<C-n>", toggle_sidebar, { buffer = ui.sidebar_buf })

  -- diff pane
  vim.keymap.set("n", "]c", function()
    hunk_move(1)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "[c", function()
    hunk_move(-1)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "]f", function()
    file_move(1)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "[f", function()
    file_move(-1)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "c", function()
    diff_comment(false)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("x", "c", function()
    diff_comment(true)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "dc", diff_delete, { buffer = ui.diff_buf })
  vim.keymap.set("n", "{", function()
    ui.app.context_lines = math.min(10, (ui.app.context_lines or 3) + 1)
    local git = require "pi.cr.git"
    git.refresh(ui.app)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "}", function()
    ui.app.context_lines = math.max(1, (ui.app.context_lines or 3) - 1)
    local git = require "pi.cr.git"
    git.refresh(ui.app)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "e", function()
    local context = M.context_at(vim.fn.line ".")
    if context then
      M.open_real_file(ui.app, context.file, context.line)
    end
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "q", function()
    M.close(ui.app)
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "?", show_help, { buffer = ui.diff_buf })
  vim.keymap.set("n", "<Esc>", function()
    focus "files"
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "<Tab>", function()
    focus "files"
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "h", function()
    focus "files"
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "l", function()
    focus "files"
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "<C-h>", function()
    focus "files"
  end, { buffer = ui.diff_buf })
  vim.keymap.set("n", "<C-n>", toggle_sidebar, { buffer = ui.diff_buf })
end

-- ---------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------

---@param app table shared review state ({files, selected, config, context_lines, finish})
function M.open(app)
  ui.app = app
  ui.files_cursor = 1
  ui.comments_cursor = 1
  ui.focus = "files"

  vim.cmd "tabnew"
  local background = vim.api.nvim_create_buf(false, true)
  vim.bo[background].bufhidden = "wipe"
  vim.api.nvim_set_current_buf(background)

  ui.sidebar_buf = create_buf()
  ui.diff_buf = create_buf()
  vim.bo[ui.diff_buf].filetype = "diff"

  ui.sidebar_win = vim.api.nvim_open_win(ui.sidebar_buf, false, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 10,
    height = 1,
  })
  ui.diff_win = vim.api.nvim_open_win(ui.diff_buf, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 10,
    height = 1,
  })
  layout()

  set_keymaps()
  M.render_all()
  focus "files"
end

return M
