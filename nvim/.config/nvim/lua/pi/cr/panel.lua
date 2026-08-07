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
  for _, row in ipairs(state.rows) do
    if not row.hidden then
      local indent = string.rep("  ", row.depth)
      if row.kind == "dir" or row.kind == "file" then
        local caret = state.folds[row.key] and "▸" or "▾"
        lines[#lines + 1] = string.format("%s%s %s (%d)", indent, caret, row.label, row.count or 0)
      else
        local prefix = string.format("[%s] :%d  ", TYPE_LABELS[row.type] or "NOTE", row.line or 0)
        local text_width = math.max(8, width - #prefix)
        lines[#lines + 1] = indent .. prefix .. truncate(row.text or "", text_width)
        if row.id == state.sel_id then
          sel_line = #lines
        end
      end
    end
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  vim.api.nvim_buf_set_extmark(state.buf, NS, 0, 0, { hl_group = "Title" })
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

---@param actions {jump: fun(id: number), delete: fun(id: number), new_comment: fun(), exit: fun()}
function M.open(actions)
  state.actions = actions
  state.folds = {}
  state.sel_id = nil
  state.rows = M.build_tree_rows(require("pi.cr.comments").comments, state.folds)

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].modifiable = false
  local width = 44
  state.win = vim.api.nvim_open_win(state.buf, false, {
    relative = "editor",
    row = 1,
    col = math.max(1, vim.o.columns - width - 1),
    width = width,
    height = math.max(1, vim.o.lines - 2),
    style = "minimal",
    border = "none",
    zindex = 90,
  })

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

  -- select the first comment, if any
  for _, row in ipairs(M.visible_rows(state.rows)) do
    if row.kind == "comment" then
      state.sel_id = row.id
      break
    end
  end
  render()
end

--- Re-render after comment add/delete (fold state and selection preserved).
function M.refresh()
  state.rows = M.build_tree_rows(require("pi.cr.comments").comments, state.folds)
  render()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, false)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win, state.buf = nil, nil
  state.actions = nil
end

M._state = state -- test/smoke hook

return M
