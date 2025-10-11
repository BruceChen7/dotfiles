---@diagnostic disable: missing-parameter
local M = {}

M.setup = function()
  local git_keymaps = {
    {
      "\\gb",
      function()
        Snacks.picker.git_branches()
      end,
      desc = "Git Branches",
    },
    {
      "<leader>gB",
      function()
        Snacks.gitbrowse()
      end,
      desc = "Git Browse",
      mode = { "n", "v" },
    },
    {
      "<leader>lg",
      function()
        Snacks.lazygit()
      end,
      desc = "Lazygit",
    },
  }

  for _, keymap in ipairs(git_keymaps) do
    vim.keymap.set(keymap.mode or "n", keymap[1], keymap[2], {
      desc = keymap.desc,
      noremap = true,
    })
  end
end

return M