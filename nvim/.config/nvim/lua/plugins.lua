local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "--single-branch",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  }
end
vim.opt.runtimepath:prepend(lazypath)

-- make sure to set `mapleader` before lazy so your mappings are correct
-- u.map("n", "<space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 引入拆分的插件配置
local plugins = {
  -- 基础配置
  concurrency = 2,
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "zip",
        "man",
        "rrhelper",
      },
    },
  },

  -- 从各个文件导入插件配置
  require "plugins.basic",
  require "plugins.completion",
  require "plugins.lsp",
  require "plugins.treesitter",
  require "plugins.themes",
  require "plugins.editing",
  require "plugins.navigation",
  require "plugins.development",
  require "plugins.utils",
  require "plugins.localization",
  require "plugins.filemanagers",
  require "plugins.special",
  require "plugins.ai",
}

require("lazy").setup(plugins)
