local harpoon = require "harpoon"

harpoon:setup {
  settings = {
    save_on_toggle = true,
    sync_on_ui_close = true,
  },
}

vim.keymap.set("n", "<space>ha", function()
  harpoon:list():add()
end, { desc = "add harpoon bookmark" })

vim.keymap.set("n", "<space>hn", function()
  harpoon:list():next()
end, { desc = "nav next bookmark" })

vim.keymap.set("n", "<space>hp", function()
  harpoon:list():prev()
end, { desc = "nav prev bookmark" })

vim.keymap.set("n", "\\hf", function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "toggle harpoon menu" })
