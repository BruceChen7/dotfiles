vim.keymap.set("n", "<space>gf", ":Git <CR>", { desc = "open fugtive" })
vim.keymap.set("n", "<space>gv", ":Gvdiffsplit <CR>", { desc = "open fugtive diff current file" })
-- u.map("n", "<space>gb", ":Gclog -- %<CR>",)
vim.keymap.set("n", "<space>gb", ":Gclog -- %<CR>", { desc = "current file history" })
