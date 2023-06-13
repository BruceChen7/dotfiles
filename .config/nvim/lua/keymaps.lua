local u = require "util"
-- https://github.com/Allaman/nvim/blob/main/lua/mappings.lua
local default_options = { noremap = true, silent = true }
local expr_options = { noremap = true, expr = true, silent = true }

-- 窗口快捷键映射
u.map("n", "<tab>h", "<c-w>h")
u.map("n", "<tab>l", "<c-w>l")
u.map("n", "<tab>j", "<c-w>j")
u.map("n", "<tab>k", "<c-w>k")
u.map("n", "<tab>0", "<c-w>L")

-- 编辑模式
u.map("i", "<c-a>", "<home>")
u.map("i", "<c-e>", "<end>")
u.map("i", "<c-d>", "<del>")
u.map("i", "<c-_>", "<c-k>")
u.map("n", "<space>p", 'viw"0p')
u.map("n", "<space>y", "yiw")

u.map("v", "<", "<gv", default_options)
u.map("v", ">", ">gv", default_options)

-- paste over currently selected text without yanking it
-- u.map("v", "p", '"_dP', default_options)

-- buffer switch
-- u.map("n", "<tab>n", ":bNext<CR>", default_options)
-- u.map("n", "<tab>p", ":bprevious<CR>", default_options)

-- Cancel search highlighting with ESC
u.map("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", default_options)

-- yank
u.map("n", "Y", "y$", default_options)

u.map("n", "W", ":w!<cr>")
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

local function home()
  local head = (vim.api.nvim_get_current_line():find "[^%s]" or 1) - 1
  local cursor = vim.api.nvim_win_get_cursor(0)
  cursor[2] = cursor[2] == head and 0 or head
  vim.api.nvim_win_set_cursor(0, cursor)
end

vim.keymap.set({ "i", "n" }, "<Home>", home)
vim.keymap.set("n", "0", home)

-- AsyncTask
vim.keymap.set("n", "g1", ":AsyncTask grep-cword<CR>")
vim.keymap.set("n", "g2", ":AsyncTask grep-todo<CR>")
-- quickfix 手动打开
u.map("n", "<space>q", ":call asyncrun#quickfix_toggle(20)<cr>")

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

vim.keymap.set("n", "g3", change_colorscheme)
vim.keymap.set("n", ",vv", ":vsplit<CR>")
vim.keymap.set("n", ",ss", ":split<CR>")

vim.keymap.set("n", "<leader>ll", function()
  file = vim.fn.expand "%:p"
  if file:find(vim.fn.expand "~/.config/nvim/", 1, true) == 1 then
    cmd = ":source " .. file
    vim.cmd(cmd)
    print(cmd .. " done")
  end
end)

local id = vim.api.nvim_create_augroup("startup", {
  clear = false,
})

local persistbuffer = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.fn.setbufvar(bufnr, "bufpersist", 1)
end

vim.api.nvim_create_autocmd({ "BufRead" }, {
  group = id,
  pattern = { "*" },
  callback = function()
    vim.api.nvim_create_autocmd({ "InsertEnter", "BufModifiedSet" }, {
      buffer = 0,
      once = true,
      callback = function()
        persistbuffer()
      end,
    })
  end,
})

vim.keymap.set("n", "<space>cu", function()
  local curbufnr = vim.api.nvim_get_current_buf()
  local buflist = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(buflist) do
    if vim.bo[bufnr].buflisted and bufnr ~= curbufnr and (vim.fn.getbufvar(bufnr, "bufpersist") ~= 1) then
      vim.cmd("bd " .. tostring(bufnr))
    end
  end
end, { silent = true, desc = "Close unused buffers" })

function retab_directory()
  local current_dir = vim.fn.expand "%:p:h"

  local function retab_file(file)
    if vim.fn.isdirectory(file) == 0 then
      vim.api.nvim_command(":e " .. file)
      vim.api.nvim_command ":set expandtab | retab"
      vim.api.nvim_command ":w"
    end
  end

  local function retab_directory_helper(dir)
    local files = vim.fn.readdir(dir)
    for _, file in ipairs(files) do
      if file ~= "." and file ~= ".." then
        local full_path = dir .. "/" .. file
        if vim.fn.isdirectory(full_path) ~= 0 then
          retab_directory_helper(full_path)
        else
          retab_file(full_path)
        end
      end
    end
  end

  retab_directory_helper(current_dir)
end

vim.keymap.set("n", "<leader>rt", retab_directory)
