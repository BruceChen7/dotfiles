local mark = require "harpoon.mark"
local ui = require "harpoon.ui"
local term = require "harpoon.term"

vim.keymap.set("n", "<space>ha", function()
  mark.add_file()
end, { desc = "add harpoon bookmark" })
-- next marks
vim.keymap.set("n", "<space>hn", function()
  ui.nav_next()
end, { desc = "nav next bookmark" })
--prev marks
vim.keymap.set("n", "<space>hp", function()
  ui.nav_prev()
end, { desc = "nav prev bookmark" })

vim.keymap.set("n", "\\hf", function()
  ui.toggle_quick_menu()
end, { desc = "toggle quick menu" })

vim.keymap.set("n", "m2", function()
  term.gotoTerminal(1)
end, { desc = "goto terminal" })
require("harpoon").setup {
  global_settings = {
    enter_on_sendcmd = true,
  },
}
