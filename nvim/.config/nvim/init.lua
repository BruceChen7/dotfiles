-- for speed up nvim load
--
require "util"
require "plugins"
require "style"
require "buildin"
require "options"
require "keymaps"

if vim.env.CR_SOCKET ~= nil and vim.env.CR_SOCKET ~= "" then
  require("pi.cr").start()
end

-- pi edit-bridge: $EDITOR prompt completion via blink.cmp
require("pi.edit-bridge").setup()

-- require "lsp"
-- require "after_init"
