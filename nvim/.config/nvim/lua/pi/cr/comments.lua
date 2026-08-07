-- pi.cr.comments: typed comments (fix/note/question), input popup with templates,
-- Comments panel data, artifact persistence, and real-file gutter signs.

local M = {}

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

---@type CrComment[]
M.comments = {}

local state = {
  next_id = 1,
  config = nil,
  sign_ids = {}, -- comment id -> sign id
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

local function comment_editor_options(input_type, title_line)
  return {
    relative = "editor",
    width = math.min(math.max(60, math.floor(vim.o.columns * 0.75)), math.max(20, vim.o.columns - 4)),
    height = math.min(math.max(6, math.floor(vim.o.lines * 0.3)), math.max(1, vim.o.lines - 6)),
    row = math.max(2, math.floor(vim.o.lines * 0.3)),
    col = 1,
    style = "minimal",
    border = "rounded",
    zindex = 100,
    title = string.format(" Pi CR comment [%s] %s ", M.type_labels[input_type], title_line),
    title_pos = "center",
  }
end

local function close_float(win, buf, return_win)
  if vim.fn.mode():sub(1, 1) == "i" then
    pcall(vim.cmd, "stopinsert")
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, false)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.bo[buf].modified = false
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  if return_win and vim.api.nvim_win_is_valid(return_win) then
    vim.api.nvim_set_current_win(return_win)
  end
end

local function open_template_picker(comment_buf, comment_win, apply)
  local picker_buf = vim.api.nvim_create_buf(false, true)
  local lines = {}
  for _, template in ipairs(M.templates) do
    table.insert(lines, string.format(" %s  %s", template.key, template.label))
  end
  vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, lines)
  vim.bo[picker_buf].bufhidden = "wipe"
  vim.bo[picker_buf].modifiable = false

  local width = 34
  local height = #lines + 1
  local win = vim.api.nvim_open_win(picker_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(1, math.floor(vim.o.lines * 0.3) + 3),
    col = math.max(1, math.floor(vim.o.columns * 0.3)),
    style = "minimal",
    border = "rounded",
    zindex = 110,
    title = " Pi CR template ",
    title_pos = "center",
  })

  local function close_picker()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
    if vim.api.nvim_buf_is_valid(picker_buf) then
      vim.api.nvim_buf_delete(picker_buf, { force = true })
    end
    vim.api.nvim_set_current_win(comment_win)
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

---@param context {file: string, line: number, end_line: number|nil, snippet: string}
function M.add(context)
  local source_win = vim.api.nvim_get_current_win()
  local input_type = "note"
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.b[bufnr].pi_cr_context = context

  local title_line = string.format("%s:%d", relative_file(context.file), context.line)
  local win = vim.api.nvim_open_win(bufnr, true, comment_editor_options(input_type, title_line))
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  local function set_title()
    vim.api.nvim_win_set_config(win, comment_editor_options(input_type, title_line))
  end

  local function cycle_type(offset)
    local index = 1
    for i, t in ipairs(M.types) do
      if t == input_type then
        index = i
        break
      end
    end
    local next_index = ((index - 1 + offset) % #M.types) + 1
    input_type = M.types[next_index]
    set_title()
  end

  local function apply_template(text)
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_put({ text }, "c", false, true)
    vim.cmd "startinsert"
  end

  local function submit()
    local comment = vim.trim(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
    if comment == "" then
      notify("CR annotation comment is empty", vim.log.levels.WARN)
      return
    end
    close_float(win, bufnr, source_win)
    M.add_comment {
      file = context.file,
      line = context.line,
      end_line = context.end_line or context.line,
      type = input_type,
      snippet = context.snippet or "",
      comment = comment,
    }
  end

  local function cancel()
    close_float(win, bufnr, source_win)
  end

  local function insert_newline()
    vim.api.nvim_put({ "" }, "c", false, true)
  end

  for _, mode in ipairs { "i", "n" } do
    vim.keymap.set(mode, "<CR>", submit, { buffer = bufnr, desc = "Submit Pi CR annotation" })
    vim.keymap.set(mode, "<Tab>", function()
      cycle_type(1)
    end, { buffer = bufnr, desc = "Cycle comment type" })
    vim.keymap.set(mode, "<S-Tab>", function()
      cycle_type(-1)
    end, { buffer = bufnr, desc = "Cycle comment type" })
    vim.keymap.set(mode, "<C-t>", function()
      open_template_picker(bufnr, win, apply_template)
    end, { buffer = bufnr, desc = "Pi CR comment template" })
    vim.keymap.set(mode, "<Esc>", cancel, { buffer = bufnr, desc = "Cancel Pi CR annotation" })
  end
  vim.keymap.set("i", "<C-c>", cancel, { buffer = bufnr, desc = "Cancel Pi CR annotation" })
  vim.keymap.set("i", "<S-CR>", insert_newline, { buffer = bufnr, desc = "Newline" })
  vim.keymap.set("i", "<C-CR>", insert_newline, { buffer = bufnr, desc = "Newline" })

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
