local U = require "util"
-- 窗口快捷键映射
U.map('n', "<tab>h", '<c-w>h')
U.map('n', "<tab>l", '<c-w>l')
U.map('n', "<tab>j", '<c-w>j')
U.map('n', "<tab>k", '<c-w>k')

-- 编辑模式
U.map('i', "<c-a>", "<home>")
U.map('i', "<c-e>", "<end>")
U.map('i', "<c-d>", "<del>")
U.map('i', "<c-_>", "<c-k>")

-- U.map('n', "<C-h>", "<left>")
-- U.map('n', "<C-j>", "<down>")
-- U.map('n', "<C-k>", "<up>")
-- U.map('n', "<C-l>", "<right>")

-- U.map('c', "<C-h>", "<left>")
-- U.map('c', "<C-j>", "<down>")
-- U.map('c', "<C-k>", "<up>")
-- U.map('c', "<C-l>", "<right>")
--
U.map('n', "W", ":w!<cr>")
U.map('n', "Q", ":q!<cr>")
U.map('i', "jj", "<ESC>")

U.map("n", "<leader>bn", ":bn<cr>")
U.map("n", "<leader>bp", ":bp<cr>")

U.map("n", "<leader>tc", ":tabnew<cr>")
U.map("n", "<leader>tq", ":tabclose<cr>")
U.map("n", "<leader>tn", ":tabnext<cr>")
U.map("n", "<leader>tp", ":tabprev<cr>")
U.map("n", "<leader>to", ":tabonly<cr>")

