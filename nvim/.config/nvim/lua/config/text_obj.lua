-- Parsers must be installed manually via :TSInstall
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua
require("nvim-treesitter").setup {
  -- Directory to install parsers and queries to
  install_dir = vim.fn.stdpath "data" .. "/site",
}

local lang =
  { "c", "cpp", "python", "json", "yaml", "ruby", "go", "lua", "make", "cmake", "bash", "cmake", "toml", "vim", "yaml" }
require("nvim-treesitter").install(lang)

vim.api.nvim_create_autocmd("FileType", {
  pattern = lang,
  callback = function()
    vim.treesitter.start()
  end,
})
