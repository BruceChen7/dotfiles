vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.loaded_gzip = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_man = 1

require("core.pack").setup {
  require "plugins.ui",
  require "plugins.editor",
  require "plugins.navigation",
  require "plugins.files",
  require "plugins.completion",
  require "plugins.lsp",
  require "plugins.treesitter",
  require "plugins.git",
  require "plugins.dev",
  require "plugins.ai",
  require "plugins.notes",
  require "plugins.tools",
}
