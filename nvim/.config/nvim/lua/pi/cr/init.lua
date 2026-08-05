-- pi.cr: entry point for the Pi CR review flow.
-- Started automatically by init.lua when CR_SOCKET is set, or explicitly via
-- `nvim -c "lua require('pi.cr').start()"` (launched by the cr-diffview extension).
--
-- Protocol (unchanged): hello -> config -> finish over the CR unix socket.
-- Annotations are also appended to an artifact JSONL file as they are saved.

local diff = require "pi.cr.diff"
local comments = require "pi.cr.comments"

local M = {}

local state = {
  started = false,
  finished = false,
  config = nil,
}

local app = {
  config = nil,
  files = {},
  selected = 1,
  context_lines = 3,
  finish = nil, -- wired below
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

-- ---------------------------------------------------------------------------
-- Socket protocol
-- ---------------------------------------------------------------------------

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
      annotations = comments.serialized_all(),
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

-- ---------------------------------------------------------------------------
-- Finish / abort
-- ---------------------------------------------------------------------------

---@param quit boolean quit nvim after submitting (true for the q flow, false for the e flow)
function app.finish(quit)
  state.finished = true
  submit_annotations(function(ok)
    if not ok then
      notify("CR callback failed; annotations remain in artifact file", vim.log.levels.WARN)
    end
    if quit then
      vim.schedule(function()
        vim.cmd "qa"
      end)
    end
  end)
end

function M.finish()
  app.finish(true)
end

function M.abort()
  comments.clear_all()
  state.finished = true
  vim.cmd "qa!"
end

function M.annotations_json()
  return vim.json.encode(comments.serialized_all())
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function M.start()
  if state.started then
    return
  end
  state.started = true
  _G.pi_cr = M

  comments.setup_signs()

  vim.api.nvim_create_user_command("CRFinish", M.finish, {})
  vim.api.nvim_create_user_command("CRAbort", M.abort, {})

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
          annotations = comments.serialized_all(),
        } .. "\n"
        pipe:write(payload, function()
          pipe:shutdown(function()
            pipe:close()
          end)
        end)
      end)
    end,
  })

  request_config(function(ok)
    if not ok then
      notify("CR config request failed", vim.log.levels.WARN)
      return
    end
    vim.schedule(function()
      app.config = state.config
      comments.set_config(state.config)
      app.files = diff.parse(diff.run(state.config.diffArgs, app.context_lines))
      if #app.files == 0 then
        notify "No changes to review"
        vim.cmd "qa"
        return
      end
      local ui = require "pi.cr.ui"
      ui.open(app)
      notify("Opened CR diffview for " .. tostring(state.config.label or ""))
    end)
  end)
end

return M
