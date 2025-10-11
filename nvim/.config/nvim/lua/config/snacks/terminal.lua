---@diagnostic disable: missing-parameter
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

  for _, keymap in ipairs(terminal_keymaps) do
    vim.keymap.set(keymap.mode or "n", keymap[1], keymap[2], {
      desc = keymap.desc,
      noremap = true,
    })
  end
end

return M