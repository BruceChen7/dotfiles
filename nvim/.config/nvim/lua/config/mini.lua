require("mini.cursorword").setup { delay = 50 }
-- https://github.com/khuedoan/dotfiles/blob/5f5035e899568718501d6c1688b816019ddc918d/.config/nvim/lua/plugins.lua#L250
require("mini.surround").setup {
  mappings = {
    add = "gza",
    delete = "gzd",
    find = "gzf",
    replace = "gzr",
    highlight = "gzh",
    update_n_lines = "gzn",
  },
}
require("mini.trailspace").setup {}

require("mini.pairs").setup {}

-- https://github.com/oncomouse/dotfiles/blob/2a58fa952eacb751ff24361efd81308716a759c1/conf/vim/lua/dotfiles/plugins/mini-nvim.lua#L104
require("mini.ai").setup {
  custom_text_objects = {
    e = function()
      local from = { line = 1, col = 1 }
      local last_line_length = #vim.fn.getline "$"
      local to = {
        line = vim.fn.line "$",
        col = last_line_length == 0 and 1 or last_line_length,
      }
      return { from = from, to = to, vis_mode = "V" }
    end,
  },
}

require("mini.files").setup {}
vim.keymap.set("n", "<leader>mf", ":lua MiniFiles.open()<CR>", { desc = "open files" })
-- require("mini.completion").setup {
--   delay = { completion = 100, info = 100, signature = 50 },
-- }
--
-- -- use c-j and c-k to navigate completion
-- vim.keymap.set("i", "<C-j>", [[pumvisible() ? "\<C-n>" : ""]], { expr = true })
-- vim.keymap.set("i", "<C-k>", [[pumvisible() ? "\<C-p>" : ""]], { expr = true })
