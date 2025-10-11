---@diagnostic disable: missing-parameter
local M = {}

M.register_keymaps = function(keymaps)
  for _, keymap in ipairs(keymaps) do
    vim.keymap.set(keymap.mode or "n", keymap[1], keymap[2], {
      desc = keymap.desc,
      noremap = true,
      nowait = keymap.nowait or false,
    })
  end
end

return M