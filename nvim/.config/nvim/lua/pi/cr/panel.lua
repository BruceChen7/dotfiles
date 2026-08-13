-- pi.cr.panel: right-side Comments dock (tree grouped by file, foldable).
-- Pure tree building lives in build_tree_rows (tested in tests/pi_cr/panel_spec.lua);
-- the window/keymap shell below is deliberately thin.

local M = {}

local NS = vim.api.nvim_create_namespace "pi-cr-panel"

local state = {
  buf = nil,
  win = nil,
  actions = nil, -- { jump(id), delete(id), new_comment(), exit() }
  sel_id = nil, -- selected comment id
  folds = {}, -- "d:<dir>" | "f:<file>" -> true (folded)
  rows = {}, -- rendered rows (from build_tree_rows)
}

local TYPE_ORDER = { fix = 1, question = 2, note = 3 }
local TYPE_LABELS = { fix = "FIX", question = "QUESTION", note = "NOTE" }
-- Highlight groups defined by pi.cr.codediff.setup_highlights (theme-aware).
local TYPE_HL = { fix = "PiCRCommentFix", question = "PiCRCommentQuestion", note = "PiCRCommentNote" }

---@class CrPanelRow
---@field depth number
---@field kind "dir"|"file"|"comment"
---@field key string "d:<dir>" or "f:<file>" (dir/file rows)
---@field label string
---@field count number|nil dir/file row comment count
---@field id number|nil comment id (comment rows)
---@field type string|nil "fix"|"question"|"note" (comment rows)
---@field line number|nil (comment rows)
---@field text string|nil comment body, newlines flattened (comment rows)
---@field hidden boolean

--- Group comments into a foldable dir/file tree.
--- Pure: value in / value out. Fold state comes in via `folds` so rendering
--- stays deterministic and testable.
---@param comments CrComment[]
---@param folds table<string, boolean>
---@return CrPanelRow[]
function M.build_tree_rows(comments, folds)
  folds = folds or {}
  ---@type table<string, table[]>
  local by_dir = {}
  ---@type string[]
  local dir_order = {}
  for _, comment in ipairs(comments) do
    local dir, base = comment.file:match "^(.*)/([^/]*)$"
    if not base then
      dir, base = "", comment.file
    end
    dir = dir or ""
    if not by_dir[dir] then
      by_dir[dir] = {}
      dir_order[#dir_order + 1] = dir
    end
    table.insert(by_dir[dir], { comment = comment, base = base })
  end
  table.sort(dir_order, function(a, b)
    if a == "" then
      return true
    end
    if b == "" then
      return false
    end
    return a < b
  end)

  local rows = {} ---@type CrPanelRow[]
  for _, dir in ipairs(dir_order) do
    local entries = by_dir[dir]
    table.sort(entries, function(a, b)
      if a.base ~= b.base then
        return a.base < b.base
      end
      if a.comment.line ~= b.comment.line then
        return a.comment.line < b.comment.line
      end
      local ta, tb = TYPE_ORDER[a.comment.type], TYPE_ORDER[b.comment.type]
      return (ta or 9) < (tb or 9)
    end)

    -- Group entries by file (stable order: first occurrence in sorted list)
    local files = {} ---@type {base: string, entries: table[]}[]
    local file_index = {}
    for _, entry in ipairs(entries) do
      local fi = file_index[entry.base]
      if not fi then
        fi = { base = entry.base, entries = {} }
        file_index[entry.base] = fi
        files[#files + 1] = fi
      end
      fi.entries[#fi.entries + 1] = entry
    end

    local dir_row = nil
    local dir_key = dir ~= "" and ("d:" .. dir) or nil
    local dir_folded = dir_key ~= nil and folds[dir_key] == true
    if dir_key then
      dir_row = {
        depth = 0,
        kind = "dir",
        key = dir_key,
        label = dir .. "/",
        count = #entries,
        hidden = false,
      }
      rows[#rows + 1] = dir_row
    end

    for _, file in ipairs(files) do
      local rel = dir ~= "" and (dir .. "/" .. file.base) or file.base
      local file_key = "f:" .. rel
      local file_folded = folds[file_key] == true
      local file_row = {
        depth = dir_row and 1 or 0,
        kind = "file",
        key = file_key,
        label = file.base,
        count = #file.entries,
        hidden = dir_folded,
      }
      rows[#rows + 1] = file_row
      if not file_folded then
        for _, entry in ipairs(file.entries) do
          local comment = entry.comment
          rows[#rows + 1] = {
            depth = file_row.depth + 1,
            kind = "comment",
            id = comment.id,
            type = comment.type,
            line = comment.line,
            end_line = comment.end_line,
            text = comment.comment:gsub("\n", " / "),
            hidden = file_row.hidden,
          }
        end
      end
    end
  end
  return rows
end

--- Visible (non-hidden) rows.
---@param rows CrPanelRow[]
---@return CrPanelRow[]
function M.visible_rows(rows)
  local out = {}
  for _, row in ipairs(rows) do
    if not row.hidden then
      out[#out + 1] = row
    end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Window shell (imperative)
-- ---------------------------------------------------------------------------

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Pi CR" })
end

local function truncate(text, width)
  local shown = vim.fn.strcharpart(text, 0, width)
  if vim.fn.strchars(text) > width then
    shown = shown .. "…"
  end
  return shown
end

--- Render the dock buffer from the current tree rows.
---
--- 工作原理：全量重写式渲染（不做增量 diff）。输入是 state.rows
--- （build_tree_rows 生成的目录/文件/评论树）与 state.sel_id（选中评论），
--- 输出是 buffer 文本 + 高亮 extmark：
---
---   1. 宽度 = 窗口宽 − 2（两侧留白），下限 24；评论正文按此截断（truncate）。
---   2. 先统计可见评论总数，生成 "Comments (N)" 标题行。
---   3. 逐行展开 rows：dir/file 行显示折叠箭头（▸/▾）+ 计数；
---      评论行显示 "[TYPE] :行号  正文"，并记录两件事——
---      选中行（sel_line，整行 Visual 高亮）或非选中行的类型前缀
---      （type_marks，按 FIX/QUESTION/NOTE 着色）。
---   4. 一次性 set_lines 写入 buffer（modifiable 临时打开再关闭），
---      清空并重放本命名空间的全部高亮 extmark（标题、类型前缀、选中行）。
---   5. 选中行通过 nvim_win_set_cursor 落位：窗口会自动滚动跟随光标，
---      因此在矮分屏（8-14 行）下长列表滚动时选中行始终可见。
---
--- 调用方：refresh/toggle/close 等任何状态变化后都会触发一次全量重绘，
--- 列表规模小（评论数），全量重写成本可忽略，换取逻辑简单。
local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local width = math.max(24, vim.api.nvim_win_get_width(state.win) - 2)

  local total = 0
  for _, row in ipairs(state.rows) do
    if not row.hidden and row.kind == "comment" then
      total = total + 1
    end
  end

  local lines = { "Comments (" .. total .. ")" }
  local sel_line = nil
  local type_marks = {} ---@type {line: number, col: number, len: number, hl: string}[]
  for _, row in ipairs(state.rows) do
    if not row.hidden then
      local indent = string.rep("  ", row.depth)
      if row.kind == "dir" or row.kind == "file" then
        local caret = state.folds[row.key] and "▸" or "▾"
        lines[#lines + 1] = string.format("%s%s %s (%d)", indent, caret, row.label, row.count or 0)
      else
        local range = row.end_line and row.end_line > row.line and string.format("%d-%d", row.line, row.end_line)
          or tostring(row.line or 0)
        local prefix = string.format("[%s] :%s  ", TYPE_LABELS[row.type] or "NOTE", range)
        local text_width = math.max(8, width - #prefix)
        lines[#lines + 1] = indent .. prefix .. truncate(row.text or "", text_width)
        if row.id == state.sel_id then
          sel_line = #lines
        else
          type_marks[#type_marks + 1] = {
            line = #lines,
            col = #indent,
            len = #("[" .. (TYPE_LABELS[row.type] or "NOTE") .. "]"),
            hl = TYPE_HL[row.type] or "PiCRCommentNote",
          }
        end
      end
    end
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  vim.api.nvim_buf_set_extmark(state.buf, NS, 0, 0, { hl_group = "Title" })
  for _, mark in ipairs(type_marks) do
    vim.api.nvim_buf_set_extmark(state.buf, NS, mark.line - 1, mark.col, {
      end_col = mark.col + mark.len,
      hl_group = mark.hl,
    })
  end
  if sel_line then
    vim.api.nvim_buf_set_extmark(state.buf, NS, sel_line - 1, 0, { hl_group = "Visual" })
    pcall(vim.api.nvim_win_set_cursor, state.win, { sel_line, 0 })
  end
end

local function move_selection(direction)
  local comments = {}
  for _, row in ipairs(M.visible_rows(state.rows)) do
    if row.kind == "comment" then
      comments[#comments + 1] = row
    end
  end
  if #comments == 0 then
    return
  end
  local idx = 1
  for i, row in ipairs(comments) do
    if row.id == state.sel_id then
      idx = i
      break
    end
  end
  idx = ((idx - 1 + direction) % #comments) + 1
  state.sel_id = comments[idx].id
  render()
end

local function toggle_fold_at_cursor()
  local line = vim.api.nvim_win_get_cursor(state.win)[1]
  local row = M.visible_rows(state.rows)[line]
  if not row or (row.kind ~= "dir" and row.kind ~= "file") then
    return
  end
  state.folds[row.key] = not state.folds[row.key]
  render()
end

local function selected_row()
  for _, row in ipairs(M.visible_rows(state.rows)) do
    if row.kind == "comment" and row.id == state.sel_id then
      return row
    end
  end
  return nil
end

---@param actions {jump: fun(id: number), delete: fun(id: number), new_comment: fun(), exit: fun(), help: fun()}
function M.register(actions)
  state.actions = actions
  state.folds = {}
  state.sel_id = nil
  state.rows = M.build_tree_rows(require("pi.cr.comments").comments, state.folds)
end

---@return boolean
local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

--- Open the dock window (no-op when already open).
---
--- Bottom real split, NOT a float. The old float overlaid the editor's right
--- side (relative=editor, col=columns-45, zindex=90), so a cursor moving
--- right in the modified diff pane passed underneath it and became invisible:
--- floats always draw above normal windows, and the diff pane extends to the
--- editor's right edge (headless repro: cursor screen col 119 sat inside the
--- dock's 76-119 overlay). A split never overlaps — diff panes keep their
--- full width and the cursor stays visible at any column; the cost is a few
--- rows of diff height (clamped 6-14, like codediff's own bottom history
--- panel). codediff's layout.arrange only resizes its own known windows and
--- its cleanup only tracks windows marked vim.w.codediff_restore, so the dock
--- split survives file switches and layout toggles untouched.
function M.open()
  if is_open() or not state.actions then
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].modifiable = false
  state.win = vim.api.nvim_open_win(state.buf, false, {
    split = "below",
  })
  vim.wo[state.win].winfixheight = true
  local height = math.min(14, math.max(6, math.floor(vim.o.lines * 0.22)))
  vim.api.nvim_win_set_height(state.win, height)

  local map = function(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = state.buf, nowait = true })
  end
  map("j", function()
    move_selection(1)
  end)
  map("k", function()
    move_selection(-1)
  end)
  map("za", toggle_fold_at_cursor)
  map("<CR>", function()
    local row = selected_row()
    if row then
      state.actions.jump(row.id)
    end
  end)
  map("d", function()
    local row = selected_row()
    if row then
      state.actions.delete(row.id)
    end
  end)
  map("c", function()
    state.actions.new_comment()
  end)
  map("q", function()
    state.actions.exit()
  end)
  map("?", function()
    if state.actions.help then
      state.actions.help()
    end
  end)
  map("<leader>cd", function()
    M.close()
  end)
  if state.actions.focus then
    for _, k in ipairs { { "<C-h>", -1 }, { "<C-k>", -1 }, { "<C-l>", 1 }, { "<C-j>", 1 } } do
      map(k[1], function()
        state.actions.focus(k[2])
      end)
    end
  end

  -- select the first comment, if any
  if not state.sel_id then
    for _, row in ipairs(M.visible_rows(state.rows)) do
      if row.kind == "comment" then
        state.sel_id = row.id
        break
      end
    end
  end
  render()
end

--- Sync the dock with the comment count: open when the first comment arrives,
--- close when the last one is deleted. Called from refresh paths.
function M.sync()
  local count = #require("pi.cr.comments").comments
  if count > 0 and not is_open() then
    M.open()
  elseif count == 0 and is_open() then
    M.close()
  end
  if is_open() then
    state.rows = M.build_tree_rows(require("pi.cr.comments").comments, state.folds)
    render()
  end
end

--- Manual toggle (<leader>cd).
function M.toggle()
  if is_open() then
    M.close()
  else
    M.open()
  end
end

--- Re-render after comment add/delete (fold state and selection preserved).
function M.refresh()
  M.sync()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, false)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win, state.buf = nil, nil
  -- state.actions intentionally kept: the dock can be re-opened via toggle/sync.
end

M._state = state -- test/smoke hook

return M
