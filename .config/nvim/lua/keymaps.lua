local U = require "util"
-- https://github.com/Allaman/nvim/blob/main/lua/mappings.lua
local default_options = {noremap = true, silent = true}
local expr_options = {noremap = true, expr = true, silent = true}


-- 设置leader key
U.map('n', '<space>', '<Nop>')
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

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

U.map("v", "<", "<gv", default_options)
U.map("v", ">", ">gv", default_options)

-- paste over currently selected text without yanking it
U.map("v", "p", "\"_dP", default_options)


-- buffer switch
U.map("n", "<tab>n", ":bNext<CR>", default_options)
U.map("n", "<tab>p", ":bprevious<CR>", default_options)

-- Cancel search highlighting with ESC
U.map("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", default_options)

-- yank
U.map("n", "Y", "y$", default_options)

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

U.map("n", "<space>gg", ":Git <CR>")
U.map("n", "<space>gv", ":Gvdiffsplit <CR>")

U.map("n", "<space>=", ":resize +3<cr>")
U.map("n", "<space>-", ":resize -3<cr>")
U.map("n", "<space>,", ":vertical resize -5<cr>")
U.map("n", "<space>.", ":vertical resize +5<cr>")

-- vim-privew
U.map('n', "<m-;>", ":PreviewTag<CR>")
U.map('n', "<m-:", ":PreviewClose<CR>")

vim.cmd([[
	function! TermExit(code)
		echom "terminal exit code: ". a:code
	endfunc

	let g:quickui_color_scheme = 'papercol dark'
	let opts = {'w':600, 'h':800, 'callback':'TermExit'}
	let opts.title = 'TIG POP'
	noremap <leader>tg :call quickui#terminal#open('tig', opts)<CR>
]])

-- 自动打开 quickfix window ，高度为 6
vim.g.asyncrun_open = 10
-- 任务结束时候响铃提醒
vim.g.asyncrun_bell = 1

-- AsyncTask
U.map('n', "g1", ":AsyncTask grep-cword<CR>")
-- quickfix 手动打开
U.map("n", "<space>q", ":call asyncrun#quickfix_toggle(10)<cr>")

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

-- lualine
require('lualine').setup()
