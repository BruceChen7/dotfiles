---@diagnostic disable: missing-parameter
local utils = require "utils"

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

  utils.register_keymaps(git_keymaps)
end

return M
