---@diagnostic disable: missing-parameter
local M = {}
local utils = require "utils"

M.setup = function()
  local news_keymaps = {
    {
      "<leader>N",
      desc = "Neovim News",
      function()
        Snacks.win {
          file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
          width = 0.6,
          height = 0.6,
          wo = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
          },
        }
      end,
    },
  }
  utils.register_keymaps(news_keymaps)
end

return M
