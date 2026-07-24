--- Dedup'd one-shot notification helper for pi edit-bridge.
--- Prevents message spam during reconnection or error bursts.

local M = {}

local shown = {}

--- Show a vim.notify message, dedup'd by key.
--- Each unique message key is shown at most once per session.
--- @param msg string  The message text
--- @param level? integer  vim.log.levels.* (default INFO)
--- @param key? string   Dedup key (defaults to msg itself)
function M.once(msg, level, key)
  key = key or msg
  if shown[key] then
    return
  end
  shown[key] = true
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Pi Edit" })
  end)
end

--- Convenience: error-level notification (always shown, not dedup'd).
--- @param msg string
function M.error(msg)
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.ERROR, { title = "Pi Edit" })
  end)
end

--- Convenience: info-level notification (always shown, not dedup'd).
--- @param msg string
function M.info(msg)
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.INFO, { title = "Pi Edit" })
  end)
end

return M
