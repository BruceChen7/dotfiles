-- for speed up nvim load
--
require "util"
-- Disable builtin plugins (netrw etc.) BEFORE lazy.nvim scans runtimepath and
-- sources $VIMRUNTIME/plugin/*. If this runs after `require "plugins"`,
-- netrwPlugin.vim registers its VimEnter autocmd before the g:loaded_netrw
-- guard exists, and `nvim .` later fails with E117 (netrw#LocalBrowseCheck).
require "buildin"
require "plugins"
require "style"
require "options"
require "keymaps"

if vim.env.CR_SOCKET ~= nil and vim.env.CR_SOCKET ~= "" then
  require("pi.cr").start()
end

-- pi edit-bridge: $EDITOR prompt completion via blink.cmp
require("pi.edit-bridge").setup()

-- require "lsp"
-- require "after_init"
