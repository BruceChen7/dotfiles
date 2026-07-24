--- blink.cmp source provider for pi edit-bridge.
---
--- Implements the blink.cmp Source interface:
---   - get_trigger_characters() → { "@", "/" }
---   - enabled() → filetype == "pi-prompt"
---   - get_completions(context, callback) → optional cancel function
---   - execute(context, item, callback, default_implementation)

local M = {}
local source = {}

local ItemKind = vim.lsp.protocol.CompletionItemKind

--- Guess the cosmetic CompletionItemKind from a pi item's value.
--- pi items do NOT carry a kind; we infer from the value prefix.
--- @param pi_item table
--- @return integer  CompletionItemKind
local function guess_kind(pi_item)
  if type(pi_item) ~= "table" then
    return ItemKind.Text
  end
  local v = (type(pi_item.value) == "string") and pi_item.value or ""
  if v:sub(-1) == "/" then
    return ItemKind.Folder
  end -- directory
  if v:sub(1, 7) == "/skill:" then
    return ItemKind.Snippet
  end -- skill template
  if v:sub(1, 1) == "/" then
    return ItemKind.Keyword
  end -- slash command
  if v:sub(1, 1) == "@" then
    return ItemKind.File
  end -- @file mention
  return ItemKind.Text
end

--- Format a pi item into a blink.cmp LSP CompletionItem.
--- Sets label, kind, detail, textEdit (for proper menu rendering), and data (for execute).
--- @param pi_item table
--- @param prefix string  The prefix captured at getSuggestions time
--- @param cursor_line string  The current line text (for textEdit range)
--- @param cursor_byte_col integer  0-indexed byte position
--- @param cursor_row integer  1-indexed row
--- @return table  blink.cmp CompletionItem
local function format_item(pi_item, prefix, cursor_line, cursor_byte_col, cursor_row)
  local coords = require "pi.edit-bridge.coords"

  -- textEdit range: 0-indexed UTF-16 positions
  local line_num = cursor_row - 1 -- 1-indexed → 0-indexed
  local prefix_utf16_len = coords.byte_to_utf16(cursor_line or "", #(prefix or ""))
  local cursor_utf16 = coords.byte_to_utf16(cursor_line or "", cursor_byte_col or 0)
  local start_char = cursor_utf16 - prefix_utf16_len
  if start_char < 0 then
    start_char = 0
  end

  return {
    label = pi_item.label or "",
    kind = guess_kind(pi_item),
    detail = (type(pi_item.description) == "string") and pi_item.description or nil,
    textEdit = {
      newText = pi_item.value or pi_item.label or "",
      range = {
        start = { line = line_num, character = start_char },
        ["end"] = { line = line_num, character = cursor_utf16 },
      },
    },
    data = pi_item, -- forwarded to execute → applyCompletion
  }
end

--------------------------------------------------------------------
--- Source constructor

--- @param opts table  Provider-specific opts from config (unused)
--- @param _config table  Full provider config (unused)
--- @return table  Source instance
function source.new(opts, _config)
  return setmetatable({}, { __index = source })
end

--- @return string[]
function source:get_trigger_characters()
  -- Include path characters so @~/work/video keeps the menu visible.
  -- Safe because this source only activates in pi-prompt buffers.
  return { "/", "@" }
end

--- @return boolean
function source:enabled()
  return vim.bo.filetype == "pi-prompt"
end

--------------------------------------------------------------------
--- get_completions

--- @param ctx table  blink.cmp Context
--- @param callback fun(response: { items: table[], is_incomplete_forward: boolean }|nil)
--- @return function|nil  cancel function
function source:get_completions(ctx, callback)
  if type(ctx) ~= "table" then
    callback { items = {}, is_incomplete_forward = false }
    return
  end

  local connection = require "pi.edit-bridge.connection"

  -- Capture cursor context for textEdit range mapping
  local cursor = vim.api.nvim_win_get_cursor(0) -- {1-indexed row, 0-indexed byte col}
  local cursor_line = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1] or ""

  local request_id = connection:get_suggestions(ctx, function(err, result)
    if err or not result or not result.items then
      callback { items = {}, is_incomplete_forward = false }
      return
    end

    local prefix = (type(result.prefix) == "string") and result.prefix or ""
    local items = {}
    for _, pi_item in ipairs(result.items) do
      if type(pi_item) == "table" then
        items[#items + 1] = format_item(pi_item, prefix, cursor_line, cursor[2], cursor[1])
      end
    end

    callback {
      items = items,
      is_incomplete_forward = result.is_incomplete or false,
    }
  end)

  if request_id then
    return function()
      connection:cancel_request(request_id)
    end
  end
end

--------------------------------------------------------------------
--- execute (accept via applyCompletion)

--- Calls applyCompletion RPC, replaces entire buffer, sets cursor.
--- Calls callback() immediately (RPC is fire-and-forget for responsiveness).
--- @param ctx table  blink.cmp Context
--- @param item table  Accepted blink.cmp CompletionItem
--- @param callback fun()
--- @param _default_implementation fun()  Unused — we overwrite wholesale
function source:execute(ctx, item, callback, _default_implementation)
  local connection = require "pi.edit-bridge.connection"
  local coords = require "pi.edit-bridge.coords"

  -- Get keyword prefix; fallback to empty
  local ok, prefix = pcall(function()
    return ctx:get_keyword()
  end)
  if not ok then
    prefix = ""
  end

  connection:apply_completion(ctx, item.data or item, prefix, function(err, result)
    if err or not result then
      return -- degrade: buffer left as-is
    end

    -- Replace entire buffer
    local new_lines = result.lines
    if type(new_lines) == "string" then
      new_lines = vim.split(new_lines, "\n")
    end
    local bufnr = (ctx and type(ctx.bufnr) == "number") and ctx.bufnr or 0
    pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, new_lines)

    -- Set cursor: result is 0-indexed UTF-16 → Neovim 0-indexed byte
    local new_cursor_line = (result.cursorLine or 0) + 1
    local target_line = new_lines[new_cursor_line] or ""
    local new_cursor_col = coords.utf16_to_byte(target_line, result.cursorCol or 0)
    pcall(vim.api.nvim_win_set_cursor, 0, { new_cursor_line, new_cursor_col })
  end)

  -- Call callback immediately — don't wait for RPC
  callback()
end

--------------------------------------------------------------------
--- Module exports

function M.new(opts, config)
  return source.new(opts, config)
end

return M
