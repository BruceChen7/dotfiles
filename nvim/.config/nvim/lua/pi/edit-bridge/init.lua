--- pi edit-bridge: Neovim-side integration for pi $EDITOR prompt completion.
---
--- Activation: on VimEnter, detects $PI_NVIM_BRIDGE environment variable
--- (set by the pi-edit-bridge pi extension). Sets filetype=pi-prompt so
--- blink.cmp's per_filetype source activates, then connects to the bridge.
---
--- blink.cmp source registration is handled statically via the provider
--- config in plugins/completion.lua (per_filetype["pi-prompt"] = "pi-edit").

local M = {}

local notify = require "pi.edit-bridge.notify"

--- Set up the pi edit-bridge.
---
--- Creates a one-shot VimEnter autocmd. If $PI_NVIM_BRIDGE is present,
--- sets filetype=pi-prompt and connects to the Unix socket.
---
--- Safe to call unconditionally — does nothing when pi is not the parent.
function M.setup()
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      local raw = vim.env.PI_NVIM_BRIDGE
      if not raw or raw == "" then
        return
      end

      local ok, info = pcall(vim.json.decode, raw)
      if not ok or type(info) ~= "table" then
        return
      end

      if info.transport ~= "unix" or not info.path or not info.token then
        return
      end

      -- Set filetype so blink.cmp per_filetype source activates
      vim.bo.filetype = "pi-prompt"

      require("pi.edit-bridge.connection"):connect(info.path, info.token)
    end,
  })
end

return M
