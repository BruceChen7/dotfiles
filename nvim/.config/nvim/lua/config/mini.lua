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
-- https://github.com/xixiaofinland/dotfiles/blob/main/.config/nvim/lua/plugins/mini.lua
-- use `if` 和 `af` 来选择函数调用
local gen_spec = require("mini.ai").gen_spec
require("mini.ai").setup {
  custom_textobjects = {
    o = gen_spec.treesitter({ a = "@loop.outer", i = "@loop.inner" }, {}),
    m = gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
    i = gen_spec.treesitter({ a = "@conditional.outer", i = "@conditional.inner" }, {}),
  },
}

-- https://github.com/pkazmier/nvim/blob/main/lua/plugins/mini/statusline.lua
require("mini.statusline").setup {}
require("mini.files").setup {
  windows = {
    preview = true,
  },
}
vim.keymap.set("n", "<leader>mf", function()
  local files = require "mini.files"
  files.open(vim.api.nvim_buf_get_name(0))
end, { desc = "open files" })
-- require("mini.completion").setup {
--   delay = { completion = 100, info = 100, signature = 50 },
-- }
--
-- -- use c-j and c-k to navigate completion
-- vim.keymap.set("i", "<C-j>", [[pumvisible() ? "\<C-n>" : ""]], { expr = true })
-- vim.keymap.set("i", "<C-k>", [[pumvisible() ? "\<C-p>" : ""]], { expr = true })

require("mini.pick").setup {
  mappings = {
    move_down = "<C-j>",
    move_up = "<C-k>",
  },
}

require("mini.extra").setup {}

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.md",
  callback = function()
    MiniTrailspace.trim()
  end,
})
