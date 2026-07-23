local M = {}

local SIGN_NAME = "PiCRAnnotation"
local SIGN_GROUP = "pi-cr-annotations"
local COMMENT_CURSOR_PADDING = "  "

local state = {
  annotation_sign_ids = {},
  annotations = {},
  floating_buf = nil,
  floating_win = nil,
  next_sign_id = 1,
  started = false,
  finished = false,
  config = nil,
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

local function env(name)
  local value = vim.env[name]
  if value == nil or value == "" then
    return nil
  end
  return value
end

local function cr_socket_path()
  return env "CR_SOCKET"
end

local function artifact_path()
  return state.config and state.config.annotationsPath or nil
end

local function diff_args()
  local config = state.config
  if not config or not config.diffArgs then
    return nil
  end
  return config.diffArgs
end

local function code_diff_visible_groups(staged, unstaged)
  require("codediff.config").options.explorer.visible_groups = {
    staged = staged,
    unstaged = unstaged,
    conflicts = true,
  }
end

local function open_code_diff(args)
  if vim.tbl_isempty(args or {}) then
    code_diff_visible_groups(false, true)
    vim.cmd { cmd = "CodeDiff", args = {} }
    notify "Opened CR diffview for unstaged changes"
    return
  end

  if args[1] == "--cached" then
    code_diff_visible_groups(true, false)
    vim.cmd { cmd = "CodeDiff", args = {} }
    notify "Opened CR diffview for staged changes"
    return
  end

  vim.cmd { cmd = "CodeDiff", args = args }
  notify("Opened CR diffview for " .. table.concat(args, " "))
end

local function current_buffer_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" then
    return name
  end
  return vim.fn.expand "%:p"
end

local function lines_context(start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return {
    file = current_buffer_path(),
    line = start_line,
    end_line = end_line,
    side = "unknown",
    snippet = table.concat(lines, "\n"),
  }
end

local function current_context()
  local line = vim.fn.line "."
  return lines_context(line, line)
end

local function visual_context()
  local start_line = vim.fn.line "v"
  local end_line = vim.fn.line "."
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  return lines_context(start_line, end_line)
end

local function diffview_file_path(path)
  local file = path:match "^diffview://.-:%d+:(/.+):%d+$"
  if not file then
    file = path:match "^diffview://.-:%d+:(/.+)$"
  end
  if not file then
    return nil
  end
  return file:gsub("^/", "")
end

local function relative_file_path(path)
  local diffview_path = diffview_file_path(path)
  if diffview_path then
    return diffview_path
  end

  local cwd = vim.in_fast_event() and vim.uv.cwd() or vim.fn.getcwd()
  if cwd and path:sub(1, #cwd + 1) == cwd .. "/" then
    return path:sub(#cwd + 2)
  end
  return path
end

local function location_label(context)
  local path = relative_file_path(context.file)
  if context.end_line and context.end_line ~= context.line then
    return string.format("%s:%d-%d", path, context.line, context.end_line)
  end
  return string.format("%s:%d", path, context.line)
end

local function comment_template(context)
  return { location_label(context) .. COMMENT_CURSOR_PADDING, "" }
end

local function comment_start_column(template_line)
  return #template_line - 1
end

local function serialized_annotation(annotation)
  local result = vim.deepcopy(annotation)
  result.file = relative_file_path(annotation.file)
  return result
end

local function serialized_annotations()
  return vim.tbl_map(serialized_annotation, state.annotations)
end

local function append_artifact(annotation)
  local path = artifact_path()
  if not path then
    return
  end

  local encoded = vim.json.encode(serialized_annotation(annotation))
  vim.fn.writefile({ encoded }, path, "a")
end

local function add_annotation(annotation)
  state.annotation_sign_ids[annotation] = state.next_sign_id
  state.next_sign_id = state.next_sign_id + 1

  table.insert(state.annotations, annotation)
  append_artifact(annotation)
  M.place_annotation_sign(annotation)
  notify("Saved CR annotation " .. tostring(#state.annotations))
end

local function annotation_at_context(context)
  for _, annotation in ipairs(state.annotations) do
    local start_line = annotation.line
    local end_line = annotation.end_line or annotation.line

    if annotation.file == context.file and context.line >= start_line and context.line <= end_line then
      return annotation
    end
  end
  return nil
end

local function close_floating_comment()
  if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
    vim.api.nvim_win_close(state.floating_win, false)
  end
  state.floating_win = nil
  state.floating_buf = nil
end

local function show_floating_comment(content)
  if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
    close_floating_comment()
    return true
  end

  local width = 0
  for _, line in ipairs(content) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(math.max(width, 40), math.floor(vim.o.columns * 0.8))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local height = math.min(#content, math.max(1, math.floor(vim.o.lines * 0.5)))

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    width = width,
    height = height,
    col = 0,
    row = 1,
    style = "minimal",
    border = "single",
    focusable = true,
    zindex = 100,
  })
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")

  state.floating_buf = buf
  state.floating_win = win

  vim.keymap.set("n", "K", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
    end
  end, { buffer = buf, desc = "Focus Pi CR annotation" })

  return true
end

local function annotation_comment(bufnr)
  return vim.trim(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
end

local function focus_rightmost_window()
  -- Prefer the rightmost real file window so LSP-backed actions keep working after Diffview opens.
  local rightmost_win = nil
  local rightmost_col = -1

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
      local col = vim.api.nvim_win_get_position(win)[2]
      if col > rightmost_col then
        rightmost_col = col
        rightmost_win = win
      end
    end
  end

  if rightmost_win then
    vim.api.nvim_set_current_win(rightmost_win)
  end
end

local function close_comment_editor(bufnr, return_win)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.bo[bufnr].modified = false
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if return_win and vim.api.nvim_win_is_valid(return_win) then
    vim.api.nvim_set_current_win(return_win)
  end
end

local function comment_editor_options()
  return {
    relative = "cursor",
    width = math.min(math.max(60, math.floor(vim.o.columns * 0.75)), math.max(20, vim.o.columns - 4)),
    height = math.min(math.max(8, math.floor(vim.o.lines * 0.35)), math.max(1, vim.o.lines - 6)),
    row = 0,
    col = 1,
    style = "minimal",
    border = "rounded",
    zindex = 100,
    title = " Pi CR annotation ",
    title_pos = "center",
  }
end

local function open_comment_buffer(context)
  local source_win = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)

  local template = comment_template(context)

  vim.api.nvim_buf_set_name(bufnr, "Pi CR annotation")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, template)
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.b[bufnr].pi_cr_context = context

  local win = vim.api.nvim_open_win(bufnr, true, comment_editor_options())
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
  vim.api.nvim_win_set_cursor(win, { 1, comment_start_column(template[1]) })

  local function save_current_annotation()
    M.save_annotation(bufnr, source_win)
  end

  local function cancel_annotation()
    close_comment_editor(bufnr, source_win)
  end

  vim.keymap.set("n", "<leader>rs", save_current_annotation, { buffer = bufnr, desc = "Save Pi CR annotation" })
  vim.keymap.set("i", "<C-s>", save_current_annotation, { buffer = bufnr, desc = "Save Pi CR annotation" })

  for _, key in ipairs { "<leader>rq", "q", "<Esc>" } do
    vim.keymap.set("n", key, cancel_annotation, { buffer = bufnr, desc = "Cancel Pi CR annotation" })
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = save_current_annotation,
  })

  vim.cmd "startinsert"
end

function M.annotate()
  open_comment_buffer(current_context())
end

function M.annotate_visual()
  open_comment_buffer(visual_context())
end

function M.save_annotation(bufnr, return_win)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local context = vim.b[bufnr].pi_cr_context or current_context()
  local comment = annotation_comment(bufnr)

  if comment == "" then
    notify("CR annotation comment is empty", vim.log.levels.WARN)
    return
  end

  context.comment = comment
  add_annotation(context)
  close_comment_editor(bufnr, return_win)
end

function M.place_annotation_sign(annotation, bufnr)
  bufnr = bufnr or vim.fn.bufnr(annotation.file)
  if bufnr == -1 then
    return
  end

  vim.fn.sign_place(state.annotation_sign_ids[annotation], SIGN_GROUP, SIGN_NAME, bufnr, {
    lnum = annotation.line,
    priority = 20,
  })
end

function M.show_annotation_under_cursor()
  local annotation = annotation_at_context(current_context())
  if not annotation then
    return false
  end

  local content = {
    "CR annotation",
    "",
    location_label(annotation),
    "",
  }
  vim.list_extend(content, vim.split(annotation.comment, "\n", { plain = true }))

  return show_floating_comment(content)
end

function M.list()
  local items = {}
  for index, annotation in ipairs(state.annotations) do
    table.insert(items, {
      filename = annotation.file,
      lnum = annotation.line,
      text = "CR[" .. index .. "] " .. annotation.comment,
    })
  end

  vim.fn.setqflist(items, "r")
  vim.cmd "copen"
end

function M.delete_annotation()
  local context = current_context()
  for index = #state.annotations, 1, -1 do
    local annotation = state.annotations[index]
    if annotation.file == context.file and annotation.line == context.line then
      local bufnr = vim.fn.bufnr(annotation.file)
      if bufnr ~= -1 then
        vim.fn.sign_unplace(SIGN_GROUP, {
          id = state.annotation_sign_ids[annotation],
          buffer = bufnr,
        })
      end
      state.annotation_sign_ids[annotation] = nil
      table.remove(state.annotations, index)
      notify("Deleted CR annotation " .. tostring(index))
      return
    end
  end

  notify("No CR annotation on this line", vim.log.levels.WARN)
end

local function submit_annotations(callback)
  local socket_path = cr_socket_path()
  if not socket_path then
    callback(false)
    return
  end

  local pipe = vim.uv.new_pipe(false)
  pipe:connect(socket_path, function(err)
    if err then
      pipe:close()
      callback(false)
      return
    end

    local payload = vim.json.encode {
      type = "finish",
      annotations = serialized_annotations(),
    } .. "\n"

    pipe:write(payload, function(write_err)
      pipe:shutdown(function()
        pipe:close()
        callback(write_err == nil)
      end)
    end)
  end)
end

local function request_config(callback)
  local socket_path = cr_socket_path()
  if not socket_path then
    callback(false)
    return
  end

  local pipe = vim.uv.new_pipe(false)
  local buffered = ""
  local completed = false

  local function finish(ok)
    if completed then
      return
    end
    completed = true
    if not pipe:is_closing() then
      pipe:close()
    end
    callback(ok)
  end

  pipe:connect(socket_path, function(err)
    if err then
      finish(false)
      return
    end

    pipe:read_start(function(read_err, chunk)
      if read_err then
        finish(false)
        return
      end
      if not chunk then
        finish(state.config ~= nil)
        return
      end

      buffered = buffered .. chunk
      while true do
        local newline = buffered:find "\n"
        if not newline then
          break
        end
        local line = buffered:sub(1, newline - 1)
        buffered = buffered:sub(newline + 1)
        local ok, config = pcall(vim.json.decode, line)
        if ok and config.type == "config" then
          state.config = config
          finish(true)
          return
        end
      end
    end)

    pipe:write(vim.json.encode { type = "hello" } .. "\n", function(write_err)
      if write_err then
        finish(false)
      end
    end)
  end)
end

function M.finish()
  state.finished = true
  submit_annotations(function(ok)
    if not ok then
      notify("CR callback failed; annotations remain in artifact file", vim.log.levels.WARN)
    end
    vim.schedule(function()
      vim.cmd "qa"
    end)
  end)
end

function M.abort()
  state.annotations = {}
  vim.cmd "qa!"
end

function M.annotations_json()
  return vim.json.encode(serialized_annotations())
end

function M.start()
  if state.started then
    return
  end
  state.started = true
  _G.pi_cr = M

  -- Initialize LSP proxy for codediff virtual buffers
  require("pi.cr-lsp").setup()

  vim.fn.sign_define(SIGN_NAME, {
    text = "✎",
    texthl = "DiagnosticSignHint",
    linehl = "",
    numhl = "",
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      for _, annotation in ipairs(state.annotations) do
        if annotation.file == name then
          M.place_annotation_sign(annotation, args.buf)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("PiCRVimLeave", { clear = true }),
    callback = function()
      if state.finished then
        return
      end

      local socket_path = cr_socket_path()
      if not socket_path then
        return
      end

      local pipe = vim.uv.new_pipe(false)
      if not pipe then
        return
      end

      pipe:connect(socket_path, function(err)
        if err then
          pipe:close()
          return
        end

        local payload = vim.json.encode {
          type = "finish",
          annotations = serialized_annotations(),
        } .. "\n"

        pipe:write(payload, function()
          pipe:shutdown(function()
            pipe:close()
          end)
        end)
      end)
    end,
  })

  vim.api.nvim_create_user_command("CRAnnotate", M.annotate, {})
  vim.api.nvim_create_user_command("CRSaveAnnotation", function()
    M.save_annotation()
  end, {})
  vim.api.nvim_create_user_command("CRList", M.list, {})
  vim.api.nvim_create_user_command("CRDeleteAnnotation", M.delete_annotation, {})
  vim.api.nvim_create_user_command("CRFinish", M.finish, {})
  vim.api.nvim_create_user_command("CRAbort", M.abort, {})

  vim.keymap.set("n", "<leader>ra", M.annotate, { desc = "Pi CR annotate line" })
  vim.keymap.set("n", "<leader>rl", M.list, { desc = "List Pi CR annotations" })
  vim.keymap.set("n", "<leader>rd", M.delete_annotation, { desc = "Delete Pi CR annotation" })
  vim.keymap.set("n", "<leader>rf", M.finish, { desc = "Finish Pi CR review" })
  vim.keymap.set("n", "<leader>rx", M.abort, { desc = "Abort Pi CR review" })

  vim.keymap.set("x", "<leader>ra", M.annotate_visual, { desc = "Pi CR annotate selection" })

  request_config(function(ok)
    if not ok then
      notify("CR config request failed", vim.log.levels.WARN)
      return
    end

    local args = diff_args()
    vim.schedule(function()
      open_code_diff(args)
      vim.defer_fn(focus_rightmost_window, 100)
    end)
  end)
end

return M
