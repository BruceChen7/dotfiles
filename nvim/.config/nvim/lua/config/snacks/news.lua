---@diagnostic disable: missing-parameter
local M = {}

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

  for _, keymap in ipairs(news_keymaps) do
    vim.keymap.set(keymap.mode or "n", keymap[1], keymap[2], {
      desc = keymap.desc,
      noremap = true,
    })
  end
end

return M