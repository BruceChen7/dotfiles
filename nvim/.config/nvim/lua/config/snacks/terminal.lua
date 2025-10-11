---@diagnostic disable: missing-parameter
local utils = require "utils"

local M = {}

M.setup = function()
  local terminal_keymaps = {
    {
      "<c-\\>",
      function()
        Snacks.terminal()
      end,
      desc = "Terminal",
      mode = { "n", "t" },
    },
  }

  utils.register_keymaps(terminal_keymaps)
end

return M

