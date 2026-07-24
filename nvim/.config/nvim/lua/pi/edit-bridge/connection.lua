--- Unix domain socket client for pi-nvim-bridge JSON-RPC 2.0 protocol.
---
--- Connection lifecycle:
---   1. connect(path, token) → TCP pipe connect
---   2. hello handshake (token auth)
---   3. Ready: send_request / get_suggestions / apply_completion
---   4. disconnect() → send bye, close pipe
---
--- Stale request handling:
---   - cancel_request(id) removes the pending callback so a late response
---     is silently dropped.
---   - blink.cmp's framework-level context.id guard provides an additional
---     safety net (completion/init.lua drops stale emissions).

local M = {}

local uv = vim.uv or vim.loop
local notify = require "pi.edit-bridge.notify"
local coords = require "pi.edit-bridge.coords"

--- @class edit-bridge.State
--- @field client uv_pipe|nil
--- @field handshake_done boolean
--- @field callbacks table<string, fun(err: any, result: any)>
--- @field next_id integer
--- @field buffer string  Accumulated partial JSONL data
local state = {
  client = nil,
  handshake_done = false,
  callbacks = {},
  next_id = 0,
  buffer = "",
}

--------------------------------------------------------------------
--- Internal helpers

local function make_id()
  state.next_id = state.next_id + 1
  return tostring(state.next_id)
end

--- Write a raw line to the socket (appends \n).
--- @param text string
local function send_raw(text)
  if state.client and not state.client:is_closing() then
    state.client:write(text .. "\n")
  end
end

--- Send a JSON-RPC 2.0 request and optionally register a callback.
--- Returns the request id (for use with cancel_request).
--- The `hello` method is allowed before handshake; all others are blocked.
--- @param method string
--- @param params table
--- @param callback? fun(err: any, result: any)
--- @return string|nil  request id
local function send_request(method, params, callback)
  if not state.client or state.client:is_closing() then
    if callback then
      callback({ message = "not connected", code = -32000 }, nil)
    end
    return nil
  end
  -- hello is the only method allowed before handshake completes
  if not state.handshake_done and method ~= "hello" then
    if callback then
      callback({ message = "handshake not complete", code = -32000 }, nil)
    end
    return nil
  end

  local id = make_id()
  if callback then
    state.callbacks[id] = callback
  end

  local request = vim.json.encode {
    jsonrpc = "2.0",
    id = id,
    method = method,
    params = params,
  }
  send_raw(request)
  return id
end

--- Process a single complete JSON line from the socket.
--- @param line string
local function handle_line(line)
  if line == "" then
    return
  end

  local ok, msg = pcall(vim.json.decode, line)
  if not ok or type(msg) ~= "table" then
    return
  end

  -- Responses have an "id" field; notifications do not
  if msg.id == nil then
    -- Notification (e.g. commandsChanged) — ignore for now
    return
  end

  local cb = state.callbacks[tostring(msg.id)]
  if cb == nil then
    return -- cancelled or unknown id
  end
  state.callbacks[tostring(msg.id)] = nil

  if msg.error then
    cb(msg.error, nil)
  else
    cb(nil, msg.result)
  end
end

--- Accumulate data and split by newlines for JSONL framing.
--- @param err string|nil
--- @param data string|nil
local function on_read(err, data)
  if err then
    notify.error("Pi bridge socket read error: " .. tostring(err))
    M.disconnect()
    return
  end

  if data == nil then
    -- EOF
    notify.once("Pi bridge connection closed", vim.log.levels.WARN, "eof")
    M.disconnect()
    return
  end

  state.buffer = state.buffer .. data

  while true do
    local nl = state.buffer:find("\n", 1, true)
    if nl == nil then
      break
    end
    local line = state.buffer:sub(1, nl - 1)
    state.buffer = state.buffer:sub(nl + 1)
    handle_line(line)
  end
end

--------------------------------------------------------------------
--- Public API

--- Connect to the pi-nvim-bridge Unix socket and authenticate.
--- @param socket_path string  Path to the .sock file
--- @param token string  32-byte hex auth token
function M:connect(socket_path, token)
  if state.client then
    M.disconnect()
  end

  state.handshake_done = false
  state.callbacks = {}
  state.buffer = ""

  local pipe = uv.new_pipe(false) -- no IPC
  if not pipe then
    notify.error "Failed to create pipe for pi bridge"
    return
  end

  pipe:connect(socket_path, function(connect_err)
    if connect_err then
      notify.error("Pi bridge connect failed: " .. tostring(connect_err))
      pipe:close()
      state.client = nil
      return
    end

    state.client = pipe
    pipe:read_start(on_read)

    -- Send hello handshake
    send_request("hello", {
      token = token,
      client = "pi-edit-bridge",
      clientVersion = "0.1.0",
    }, function(err, result)
      if err then
        notify.error("Pi bridge handshake failed: " .. (err.message or tostring(err)))
        M.disconnect()
        return
      end

      state.handshake_done = true
      notify.info "Connected to pi"
    end)
  end)
end

--- Disconnect from pi and clean up.
function M:disconnect()
  if state.client and not state.client:is_closing() then
    -- Graceful bye
    if state.handshake_done then
      local bye = vim.json.encode {
        jsonrpc = "2.0",
        id = make_id(),
        method = "bye",
        params = {},
      }
      state.client:write(bye .. "\n")
    end
    state.client:read_stop()
    state.client:close()
  end

  state.client = nil
  state.handshake_done = false
  state.buffer = ""

  -- Fail all pending callbacks
  for id, cb in pairs(state.callbacks) do
    state.callbacks[id] = nil
    cb({ message = "disconnected", code = -32001 }, nil)
  end
end

--- Resolve cursor from context or Neovim API as fallback.
--- blink.cmp context may not always have a cursor field.
--- @param context table
--- @return integer row (1-indexed), integer col (0-indexed byte)
local function resolve_cursor(context)
  if context and context.cursor then
    return context.cursor[1], context.cursor[2]
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1], cursor[2]
end

--- Fetch completions from pi for the current buffer context.
--- @param context table  blink.cmp.Context (or partial fallback)
--- @param callback fun(err: any, result: table|nil)
--- @return string|nil  request id (for cancellation)
function M:get_suggestions(context, callback)
  local cursor_row, cursor_col = resolve_cursor(context)

  -- Convert Neovim byte col to pi UTF-16 code-unit col
  local line = vim.api.nvim_buf_get_lines(0, cursor_row - 1, cursor_row, false)[1] or ""
  local utf16_col = coords.byte_to_utf16(line, cursor_col)

  return send_request("getSuggestions", {
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
    cursorLine = cursor_row - 1, -- 1-indexed → 0-indexed
    cursorCol = utf16_col,
  }, callback)
end

--- Apply a completion item from pi.
--- @param context table  blink.cmp.Context (or partial fallback)
--- @param item table  Original pi completion item
--- @param prefix string  Current keyword prefix
--- @param callback fun(err: any, result: { lines: string[], cursorLine: integer, cursorCol: integer }|nil)
function M:apply_completion(context, item, prefix, callback)
  local cursor_row, cursor_col = resolve_cursor(context)

  local line = vim.api.nvim_buf_get_lines(0, cursor_row - 1, cursor_row, false)[1] or ""
  local utf16_col = coords.byte_to_utf16(line, cursor_col)

  send_request("applyCompletion", {
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
    cursorLine = cursor_row - 1,
    cursorCol = utf16_col,
    item = item.data or item,
    prefix = prefix,
  }, callback)
end

--- Cancel a pending request by id.
--- The callback will not be called when the response arrives.
--- @param id string
function M:cancel_request(id)
  state.callbacks[id] = nil
end

--- @export
M.send_request = send_request

return M
