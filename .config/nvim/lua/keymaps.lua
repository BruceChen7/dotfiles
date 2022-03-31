local u = require "util"
-- https://github.com/Allaman/nvim/blob/main/lua/mappings.lua
local default_options = { noremap = true, silent = true }
local expr_options = { noremap = true, expr = true, silent = true }

-- 设置leader key
u.map("n", "<space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 窗口快捷键映射
u.map("n", "<tab>h", "<c-w>h")
u.map("n", "<tab>l", "<c-w>l")
u.map("n", "<tab>j", "<c-w>j")
u.map("n", "<tab>k", "<c-w>k")

-- 编辑模式
u.map("i", "<c-a>", "<home>")
u.map("i", "<c-e>", "<end>")
u.map("i", "<c-d>", "<del>")
u.map("i", "<c-_>", "<c-k>")

u.map("v", "<", "<gv", default_options)
u.map("v", ">", ">gv", default_options)

-- paste over currently selected text without yanking it
u.map("v", "p", '"_dP', default_options)

-- buffer switch
u.map("n", "<tab>n", ":bNext<CR>", default_options)
u.map("n", "<tab>p", ":bprevious<CR>", default_options)

-- Cancel search highlighting with ESC
u.map("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", default_options)

-- yank
u.map("n", "Y", "y$", default_options)

u.map("n", "W", ":w!<cr>")
u.map("n", "Q", ":q!<cr>")
u.map("i", "jj", "<ESC>")

u.map("n", "<leader>bn", ":bn<cr>")
u.map("n", "<leader>bp", ":bp<cr>")

u.map("n", "<leader>tc", ":tabnew<cr>")
u.map("n", "<leader>tq", ":tabclose<cr>")
u.map("n", "<leader>tn", ":tabnext<cr>")
u.map("n", "<leader>tp", ":tabprev<cr>")
u.map("n", "<leader>to", ":tabonly<cr>")

u.map("n", "<space>=", ":resize +3<cr>")
u.map("n", "<space>-", ":resize -3<cr>")
u.map("n", "<space>,", ":vertical resize -5<cr>")
u.map("n", "<space>.", ":vertical resize +5<cr>")

-- vim-preview
u.map("n", "<m-;>", ":PreviewTag<CR>")
u.map("n", "<m-:", ":PreviewClose<CR>")

-- 自动打开 quickfix window ，高度为 10
vim.g.asyncrun_open = 10

-- 任务结束时候响铃提醒
vim.g.asyncrun_bell = 1

-- AsyncTask
vim.keymap.set("n", "g1", ":AsyncTask grep-cword<CR>")
vim.keymap.set("n", "g2", ":AsyncTask grep-todo<CR>")
-- quickfix 手动打开
u.map("n", "<space>q", ":call asyncrun#quickfix_toggle(20)<cr>")

-- tab keymap
vim.keymap.set("n", "<m-1>", ":tabn 1<cr>")
u.map("n", "<m-2>", ":tabn 2<cr>")
u.map("n", "<m-3>", ":tabn 3<cr>")
u.map("n", "<m-4>", ":tabn 4<cr>")
u.map("n", "<m-5>", ":tabn 5<cr>")
u.map("n", "<m-6>", ":tabn 6<cr>")
u.map("n", "<m-7>", ":tabn 7<cr>")
u.map("n", "<m-8>", ":tabn 8<cr>")
u.map("n", "<m-9>", ":tabn 9<cr>")
u.map("n", "<m-0>", ":tabn 10<cr>")

u.map("i", "<m-1>", "<ESC>:tabn 1<cr>")
u.map("i", "<m-2>", "<ESC>:tabn 2<cr>")
u.map("i", "<m-3>", "<ESC>:tabn 3<cr>")
u.map("i", "<m-4>", "<ESC>:tabn 4<cr>")
u.map("i", "<m-5>", "<ESC>:tabn 5<cr>")
u.map("i", "<m-6>", "<ESC>:tabn 6<cr>")
u.map("i", "<m-7>", "<ESC>:tabn 7<cr>")
u.map("i", "<m-8>", "<ESC>:tabn 8<cr>")
u.map("i", "<m-9>", "<ESC>:tabn 9<cr>")
u.map("i", "<m-0>", "<ESC>:tabn 10<cr>")

u.map("n", "\\t", ":tabnew<CR>")
u.map("n", "\\d", ":tabclose<cr>")
u.map("n", "\\1", ":tabn 1<cr>")
u.map("n", "\\2", ":tabn 2<cr>")
u.map("n", "\\3", ":tabn 3<cr>")
u.map("n", "\\4", ":tabn 4<cr>")
u.map("n", "\\5", ":tabn 5<cr>")
u.map("n", "\\6", ":tabn 6<cr>")
u.map("n", "\\7", ":tabn 7<cr>")
u.map("n", "\\8", ":tabn 8<cr>")
u.map("n", "\\9", ":tabn 9<cr>")
-- avoid slowly to wait to parse \\1
u.map("n", "\\0", ":tabn 10<cr>")

function quitWindow()
  local buf_total_num = vim.fn.len(vim.fn.getbufinfo { buflisted = 1 })
  if buf_total_num ~= 1 then
    vim.api.nvim_command "VemTablineDelete"
  else
    vim.api.nvim_command "quit!"
  end
end

if vim.fn.exists ":VemTablineGo" then
  -- always show number
  vim.g.vem_tabline_show_number = "index"
  -- alway show tabline
  vim.g.vem_tabline_show = 2

  -- tab keymap
  u.map("n", "<m-1>", ":VemTablineGo 1<cr>")
  u.map("n", "<m-2>", ":VemTablineGo 2<cr>")
  u.map("n", "<m-3>", ":VemTablineGo 3<cr>")
  u.map("n", "<m-4>", ":VemTablineGo 4<cr>")
  u.map("n", "<m-5>", ":VemTablineGo 5<cr>")
  u.map("n", "<m-6>", ":VemTablineGo 6<cr>")
  u.map("n", "<m-7>", ":VemTablineGo 7<cr>")
  u.map("n", "<m-8>", ":VemTablineGo 8<cr>")
  u.map("n", "<m-9>", ":VemTablineGo 9<cr>")
  u.map("n", "<m-0>", ":VemTablineGo 10<cr>")

  u.map("i", "<m-1>", "<ESC>:VemTablineGo 1<cr>")
  u.map("i", "<m-2>", "<ESC>:VemTablineGo 2<cr>")
  u.map("i", "<m-3>", "<ESC>:VemTablineGo 3<cr>")
  u.map("i", "<m-4>", "<ESC>:VemTablineGo 4<cr>")
  u.map("i", "<m-5>", "<ESC>:VemTablineGo 5<cr>")
  u.map("i", "<m-6>", "<ESC>:VemTablineGo 6<cr>")
  u.map("i", "<m-7>", "<ESC>:VemTablineGo 7<cr>")
  u.map("i", "<m-8>", "<ESC>:VemTablineGo 8<cr>")
  u.map("i", "<m-9>", "<ESC>:VemTablineGo 9<cr>")
  u.map("i", "<m-0>", "<ESC>:VemTablineGo 10<cr>")

  u.map("n", "\\t", ":tabnew<CR>")
  u.map("n", "\\d", ":tabclose<cr>")
  u.map("n", "\\1", ":VemTablineGo 1<cr>")
  u.map("n", "\\2", ":VemTablineGo 2<cr>")
  u.map("n", "\\3", ":VemTablineGo 3<cr>")
  u.map("n", "\\4", ":VemTablineGo 4<cr>")
  u.map("n", "\\5", ":VemTablineGo 5<cr>")
  u.map("n", "\\6", ":VemTablineGo 6<cr>")
  u.map("n", "\\7", ":VemTablineGo 7<cr>")
  u.map("n", "\\8", ":VemTablineGo 8<cr>")
  u.map("n", "\\9", ":VemTablineGo 9<cr>")
  -- avoid slowly to wait to parse \\1
  u.map("n", "\\0", ":VemTablineGo 10<cr>")
  vim.cmd [[
        command -nargs=0 VemTablineDelete call vem_tabline#tabline.delete_buffer()
    ]]
  -- quit window
  u.map("n", "Q", ":lua quitWindow()<cr>")
end

local present, pounce = pcall(require, "pounce")
if present then
  u.map("n", "s", ":Pounce<CR>")
  u.map("n", "S", ":PounceRepeat<CR>")
  u.map("v", "s", ":Pounce<CR>")
  u.map("o", "gs", ":Pounce<CR>")
end
function change_colorscheme()
  file = "~/.config/nvim/lua/style.lua"
  cmd = ":source " .. file
  vim.cmd(cmd)
  print(cmd .. " done")
end

vim.keymap.set("n", "<leader>c", change_colorscheme)
vim.keymap.set("n", "<leader>ll", function()
  file = vim.fn.expand "%:p"
  if file:find(vim.fn.expand "~/.config/nvim/", 1, true) == 1 then
    cmd = ":source " .. file
    vim.cmd(cmd)
    print(cmd .. " done")
  end
end)
