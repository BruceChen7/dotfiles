-- pi.cr.comments: typed comments (fix/note/question), input popup with templates,
-- Comments panel data, artifact persistence, and real-file gutter signs.

local M = {}

local map = require "pi.cr.map"

local SIGN_NAME = "PiCRAnnotation"
local SIGN_GROUP = "pi-cr-annotations"

M.types = { "fix", "note", "question" }

M.type_labels = {
  fix = "FIX",
  note = "NOTE",
  question = "QUESTION",
}

M.templates = {
  { key = "e", label = "Extract", text = "Extract this into a separate function/component" },
  { key = "r", label = "Rename", text = "Rename to: " },
  { key = "m", label = "Move", text = "Move this to a separate file" },
  { key = "t", label = "Types", text = "Add proper types" },
  { key = "h", label = "Error handling", text = "Add error handling" },
  { key = "p", label = "Performance", text = "Performance concern: " },
  { key = "s", label = "Simplify", text = "Simplify this" },
  { key = "d", label = "Delete", text = "Remove this" },
}

---@class CrComment
---@field id number
---@field file string
---@field line number
---@field end_line number|nil
---@field type "fix"|"note"|"question"
---@field snippet string
---@field comment string
---@field context CrCommentContext|nil

---@type CrComment[]
M.comments = {}

local state = {
  next_id = 1,
  config = nil,
  sign_ids = {}, -- comment id -> sign id
  ui = {
    editor_win = nil,
    editor_buf = nil,
    context_win = nil,
    context_buf = nil,
    picker_win = nil,
    picker_buf = nil,
    source_win = nil,
    tabpage = nil,
    closing = false,
    autocmds_ready = false,
  },
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

function M.set_config(config)
  state.config = config
end

---@param comment CrComment
local function relative_file(path)
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  if cwd and path:sub(1, #cwd + 1) == cwd .. "/" then
    return path:sub(#cwd + 2)
  end
  return path
end

---@param comment CrComment
local function serialized(comment)
  return {
    file = relative_file(comment.file),
    line = comment.line,
    end_line = comment.end_line,
    type = comment.type,
    side = "new",
    snippet = comment.snippet,
    comment = comment.comment,
  }
end

---@param comment CrComment
local function append_artifact(comment)
  if not state.config or not state.config.annotationsPath then
    return
  end
  local encoded = vim.json.encode(serialized(comment))
  vim.fn.writefile({ encoded }, state.config.annotationsPath, "a")
end

---@param comment CrComment
local function place_sign(comment)
  if not state.config then
    return
  end
  local bufnr = vim.fn.bufnr(comment.file)
  if bufnr == -1 then
    return
  end
  local sign_id = vim.fn.sign_place(0, SIGN_GROUP, SIGN_NAME, bufnr, {
    lnum = comment.line,
    priority = 20,
  })
  state.sign_ids[comment.id] = sign_id
end

local function refresh()
  pcall(function()
    require("pi.cr.codediff").redraw_all()
  end)
end

---@param comment CrComment
function M.add_comment(comment)
  comment.id = state.next_id
  state.next_id = state.next_id + 1
  table.insert(M.comments, comment)
  append_artifact(comment)
  place_sign(comment)
  notify("Saved CR annotation " .. tostring(#M.comments))
  refresh()
end

function M.clear_all()
  for _, comment in ipairs(M.comments) do
    local sign_id = state.sign_ids[comment.id]
    if sign_id then
      pcall(vim.fn.sign_unplace, SIGN_GROUP, { id = sign_id })
    end
  end
  state.sign_ids = {}
  M.comments = {}
  -- Discard semantics: wipe the artifact file too. Comments are appended to
  -- the JSONL as they are saved, and the extension falls back to that file
  -- when the finish handshake does not land (async race / crash). Clearing
  -- only memory would leak the comments to Pi on the fallback path.
  if state.config and state.config.annotationsPath then
    pcall(vim.fn.writefile, {}, state.config.annotationsPath)
  end
end

---@param id number
function M.delete_by_id(id)
  for index, comment in ipairs(M.comments) do
    if comment.id == id then
      local sign_id = state.sign_ids[id]
      if sign_id then
        pcall(vim.fn.sign_unplace, SIGN_GROUP, { id = sign_id })
      end
      state.sign_ids[id] = nil
      table.remove(M.comments, index)
      notify("Deleted CR annotation " .. tostring(index))
      refresh()
      return
    end
  end
  notify("No CR annotation with that id", vim.log.levels.WARN)
end

---@param file string
---@param line number
---@return number|nil comment id
function M.delete_at(file, line)
  for index, comment in ipairs(M.comments) do
    if comment.file == file and line >= comment.line and line <= (comment.end_line or comment.line) then
      local id = comment.id
      local sign_id = state.sign_ids[id]
      if sign_id then
        pcall(vim.fn.sign_unplace, SIGN_GROUP, { id = sign_id })
      end
      state.sign_ids[id] = nil
      table.remove(M.comments, index)
      notify("Deleted CR annotation " .. tostring(index))
      refresh()
      return id
    end
  end
  notify("No CR annotation on this line", vim.log.levels.WARN)
  return nil
end

---@param file string
---@param line number
---@return CrComment|nil
function M.at(file, line)
  for _, comment in ipairs(M.comments) do
    if comment.file == file and line >= comment.line and line <= (comment.end_line or comment.line) then
      return comment
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Comment input popup
-- ---------------------------------------------------------------------------

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function close_window(win, buf)
  if valid_win(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  if valid_buf(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

local function popup_position(source_win, width, height)
  local source = { row = 1, col = 1, cursor_row = 1, cursor_col = 0 }
  if valid_win(source_win) then
    local ok_pos, pos = pcall(vim.api.nvim_win_get_position, source_win)
    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, source_win)
    if ok_pos and ok_cursor then
      source = { row = pos[1], col = pos[2], cursor_row = cursor[1], cursor_col = cursor[2] }
    end
  end
  local geometry = map.popup_geometry(source, { lines = vim.o.lines, columns = vim.o.columns }, {
    width = width,
    height = height,
  })
  return geometry.row, geometry.col
end

local function editor_options(input_type, title_line, row, col, width, height)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    zindex = 100,
    title = string.format(" Pi CR comment [%s] %s ", M.type_labels[input_type], title_line),
    title_pos = "center",
  }
end

local function context_options(row, col, width, height, title)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    zindex = 99,
    title = " " .. title .. " ",
    title_pos = "left",
  }
end

function M.close_ui(reason)
  local ui = state.ui
  if ui.closing then
    return
  end
  ui.closing = true
  if vim.fn.mode():sub(1, 1) == "i" then
    pcall(vim.cmd, "stopinsert")
  end
  close_window(ui.picker_win, ui.picker_buf)
  close_window(ui.context_win, ui.context_buf)
  close_window(ui.editor_win, ui.editor_buf)
  local source_win = ui.source_win
  ui.editor_win, ui.editor_buf = nil, nil
  ui.context_win, ui.context_buf = nil, nil
  ui.picker_win, ui.picker_buf = nil, nil
  ui.source_win, ui.tabpage = nil, nil
  ui.closing = false
  local owner_tab = state.ui.tabpage
  if
    reason ~= "codediff-close"
    and valid_win(source_win)
    and owner_tab
    and vim.api.nvim_tabpage_is_valid(owner_tab)
    and vim.api.nvim_get_current_tabpage() == owner_tab
  then
    pcall(vim.api.nvim_set_current_win, source_win)
  end
end

local function ensure_ui_autocmds()
  if state.ui.autocmds_ready then
    return
  end
  state.ui.autocmds_ready = true
  local group = vim.api.nvim_create_augroup("PiCRCommentUI", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      local id = tonumber(args.match)
      local ui = state.ui
      if ui.closing then
        return
      end
      if id == ui.editor_win or id == ui.context_win or id == ui.picker_win then
        M.close_ui "window-closed"
      end
    end,
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      local owner = state.ui.tabpage
      if owner and not vim.api.nvim_tabpage_is_valid(owner) then
        M.close_ui "owner-tab-closed"
      end
    end,
  })
end

local function open_template_picker(comment_win, apply)
  local ui = state.ui
  local picker_buf = vim.api.nvim_create_buf(false, true)
  local lines = {}
  for _, template in ipairs(M.templates) do
    lines[#lines + 1] = string.format(" %s  %s", template.key, template.label)
  end
  vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, lines)
  vim.bo[picker_buf].bufhidden = "wipe"
  vim.bo[picker_buf].modifiable = false

  local width, height = 34, #lines + 1
  local row, col = popup_position(comment_win, width, height)
  local picker_win = vim.api.nvim_open_win(picker_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    zindex = 110,
    title = " Pi CR template ",
    title_pos = "center",
  })
  ui.picker_buf, ui.picker_win = picker_buf, picker_win

  local function close_picker()
    if valid_win(picker_win) then
      pcall(vim.api.nvim_win_close, picker_win, true)
    end
    if valid_buf(picker_buf) then
      pcall(vim.api.nvim_buf_delete, picker_buf, { force = true })
    end
    ui.picker_win, ui.picker_buf = nil, nil
    if valid_win(comment_win) then
      vim.api.nvim_set_current_win(comment_win)
    end
  end

  for _, template in ipairs(M.templates) do
    vim.keymap.set("n", template.key, function()
      close_picker()
      apply(template.text)
    end, { buffer = picker_buf, nowait = true })
  end
  vim.keymap.set("n", "q", close_picker, { buffer = picker_buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_picker, { buffer = picker_buf, nowait = true })
end

---@param context {file: string, line: number, end_line: number|nil, snippet: string, context: CrCommentContext|nil}
function M.add(context)
  ensure_ui_autocmds()
  M.close_ui "replace"
  local source_win = vim.api.nvim_get_current_win()
  local ui = state.ui
  ui.source_win = source_win
  ui.tabpage = vim.api.nvim_get_current_tabpage()
  local input_type = "note"
  local editor_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(editor_buf, 0, -1, false, { "" })
  vim.bo[editor_buf].bufhidden = "wipe"
  vim.bo[editor_buf].filetype = "markdown"
  vim.b[editor_buf].pi_cr_context = context

  local comment_context = map.normalize_context(context.context or {
    lines = nil,
    start_line = nil,
    anchor_line = nil,
    snippet = context.snippet,
  }, context.line)
  local context_lines = comment_context.lines
  local context_start = comment_context.start_line
  local context_anchor = comment_context.anchor_line
  if #context_lines == 0 then
    context_lines = { "(no source context)" }
    context_start = context.line
    comment_context = {
      lines = context_lines,
      start_line = context_start,
      end_line = context_start,
      anchor_line = context_anchor,
    }
  end
  local context_buf = vim.api.nvim_create_buf(false, true)
  local rendered_context = {}
  for index, text in ipairs(context_lines) do
    rendered_context[#rendered_context + 1] = string.format("%5d  %s", context_start + index - 1, text)
  end
  vim.api.nvim_buf_set_lines(context_buf, 0, -1, false, rendered_context)
  vim.bo[context_buf].bufhidden = "wipe"
  vim.bo[context_buf].modifiable = false
  vim.bo[context_buf].filetype = "diff"

  local width = math.min(math.max(60, math.floor(vim.o.columns * 0.62)), math.max(30, vim.o.columns - 4))
  local editor_height = math.min(8, math.max(6, vim.o.lines - 8))
  local context_height = math.min(math.max(3, #rendered_context), 8)
  local total_height = context_height + editor_height + 2
  local row, col = popup_position(source_win, width, total_height)
  local context_win = vim.api.nvim_open_win(
    context_buf,
    false,
    context_options(row, col, width, context_height, " context · read-only ")
  )
  local editor_win = vim.api.nvim_open_win(
    editor_buf,
    true,
    editor_options(
      input_type,
      string.format("%s:%d", relative_file(context.file), context.line),
      row + context_height + 1,
      col,
      width,
      editor_height
    )
  )
  ui.editor_win, ui.editor_buf = editor_win, editor_buf
  ui.context_win, ui.context_buf = context_win, context_buf
  vim.api.nvim_win_set_cursor(editor_win, { 1, 0 })

  local ns = vim.api.nvim_create_namespace "pi-cr-comment-context"
  local anchor_index = context_anchor - context_start + 1
  if anchor_index >= 1 and anchor_index <= #rendered_context then
    vim.api.nvim_buf_set_extmark(context_buf, ns, anchor_index - 1, 0, { line_hl_group = "CursorLine" })
  end

  local function set_title()
    vim.api.nvim_win_set_config(
      editor_win,
      editor_options(
        input_type,
        string.format("%s:%d", relative_file(context.file), context.line),
        row + context_height + 1,
        col,
        width,
        editor_height
      )
    )
  end
  local function cycle_type(offset)
    local index = 1
    for i, type in ipairs(M.types) do
      if type == input_type then
        index = i
        break
      end
    end
    input_type = M.types[((index - 1 + offset) % #M.types) + 1]
    set_title()
  end
  local function apply_template(text)
    if valid_win(editor_win) then
      vim.api.nvim_set_current_win(editor_win)
      vim.api.nvim_put({ text }, "c", false, true)
      vim.cmd "startinsert"
    end
  end
  local function submit()
    local comment = vim.trim(table.concat(vim.api.nvim_buf_get_lines(editor_buf, 0, -1, false), "\n"))
    if comment == "" then
      notify("CR annotation comment is empty", vim.log.levels.WARN)
      return
    end
    M.close_ui "submit"
    M.add_comment {
      file = context.file,
      line = context.line,
      end_line = context.end_line or context.line,
      type = input_type,
      snippet = context.snippet or comment,
      context = comment_context,
      comment = comment,
    }
  end
  local function cancel()
    M.close_ui "cancel"
  end
  local function insert_newline()
    vim.api.nvim_put({ "" }, "c", false, true)
  end
  for _, mode in ipairs { "i", "n" } do
    vim.keymap.set(mode, "<CR>", submit, { buffer = editor_buf, desc = "Submit Pi CR annotation" })
    vim.keymap.set(mode, "<Tab>", function()
      cycle_type(1)
    end, { buffer = editor_buf, desc = "Cycle comment type" })
    vim.keymap.set(mode, "<S-Tab>", function()
      cycle_type(-1)
    end, { buffer = editor_buf, desc = "Cycle comment type" })
    vim.keymap.set(mode, "<C-t>", function()
      open_template_picker(editor_win, apply_template)
    end, { buffer = editor_buf, desc = "Pi CR comment template" })
    vim.keymap.set(mode, "<Esc>", cancel, { buffer = editor_buf, desc = "Cancel Pi CR annotation" })
  end
  vim.keymap.set("i", "<C-c>", cancel, { buffer = editor_buf, desc = "Cancel Pi CR annotation" })
  vim.keymap.set("i", "<S-CR>", insert_newline, { buffer = editor_buf, desc = "Newline" })
  vim.keymap.set("i", "<C-CR>", insert_newline, { buffer = editor_buf, desc = "Newline" })
  vim.cmd "startinsert"
end

--- Serialize all comments for the finish payload.
---@return table[]
function M.serialized_all()
  local out = {}
  for _, comment in ipairs(M.comments) do
    table.insert(out, serialized(comment))
  end
  return out
end

function M.setup_signs()
  vim.fn.sign_define(SIGN_NAME, {
    text = "✎",
    texthl = "DiagnosticSignHint",
    linehl = "",
    numhl = "",
  })
  vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      for _, comment in ipairs(M.comments) do
        if comment.file == name then
          place_sign(comment)
        end
      end
    end,
  })
end

return M
