local u = require "util"
-- https://github.com/Allaman/nvim/blob/main/lua/mappings.lua
local default_options = {noremap = true, silent = true}
local expr_options = {noremap = true, expr = true, silent = true}


-- 设置leader key
u.map('n', '<space>', '<Nop>')
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 窗口快捷键映射
u.map('n', "<tab>h", '<c-w>h')
u.map('n', "<tab>l", '<c-w>l')
u.map('n', "<tab>j", '<c-w>j')
u.map('n', "<tab>k", '<c-w>k')

-- 编辑模式
u.map('i', "<c-a>", "<home>")
u.map('i', "<c-e>", "<end>")
u.map('i', "<c-d>", "<del>")
u.map('i', "<c-_>", "<c-k>")

u.map("v", "<", "<gv", default_options)
u.map("v", ">", ">gv", default_options)

-- paste over currently selected text without yanking it
u.map("v", "p", "\"_dP", default_options)


-- buffer switch
u.map("n", "<tab>n", ":bNext<CR>", default_options)
u.map("n", "<tab>p", ":bprevious<CR>", default_options)

-- Cancel search highlighting with ESC
u.map("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", default_options)

-- yank
u.map("n", "Y", "y$", default_options)

u.map('n', "W", ":w!<cr>")
u.map('n', "Q", ":q!<cr>")
u.map('i', "jj", "<ESC>")

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
u.map('n', "<m-;>", ":PreviewTag<CR>")
u.map('n', "<m-:", ":PreviewClose<CR>")

vim.cmd([[
	function! TermExit(code)
		echom "terminal exit code: ". a:code
	endfunc

	let g:quickui_color_scheme = 'papercol dark'
	let opts = {'w':600, 'h':800, 'callback':'TermExit'}
	let opts.title = 'TIG POP'
	noremap <leader>tg :call quickui#terminal#open('tig', opts)<CR>
]])

-- 自动打开 quickfix window ，高度为 10
vim.g.asyncrun_open = 10
-- 任务结束时候响铃提醒
vim.g.asyncrun_bell = 1

-- AsyncTask
u.map('n', "g1", ":AsyncTask grep-cword<CR>")
-- quickfix 手动打开
u.map("n", "<space>q", ":call asyncrun#quickfix_toggle(10)<cr>")

-- Treesitter configuration
-- Parsers must be installed manually via :TSInstall
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua
require('nvim-treesitter.configs').setup {
  highlight = {
    enable = true, -- false will disable the whole extension
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = 'gnn',
      node_incremental = 'grn',
      scope_incremental = 'grc',
      node_decremental = 'grm',
    },
  },
  indent = {
    enable = true,
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        [']m'] = '@function.outer',
        [']]'] = '@class.outer',
      },
      goto_next_end = {
        [']M'] = '@function.outer',
        [']['] = '@class.outer',
      },
      goto_previous_start = {
        ['[m'] = '@function.outer',
        ['[['] = '@class.outer',
      },
      goto_previous_end = {
        ['[M'] = '@function.outer',
        ['[]'] = '@class.outer',
      },
    },
  },
}
-- tab keymap
u.map("n", "<m-1>", ":tabn 1<cr>")
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
u.map("n", "\\10", ":tabn 10<cr>")
