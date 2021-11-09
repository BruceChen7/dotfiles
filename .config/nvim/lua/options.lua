local o = vim.o
local g = vim.g
local U = require('util')
-- 自动缩进
o.autoindent = true

-- 打开 C/C++ 语言缩进优化
o.cindent = true
o.nu = true
o.wrap = false
o.termguicolors = true

o.ttimeout = true
o.ttimeoutlen = 50

o.ignorecase = true

-- 智能搜索大小写判断，默认忽略大小写，除非搜索内容包含大写字母
o.smartcase = true
o.hlsearch = true
o.incsearch = true
-- 显示关标位置
o.ruler = true

o.showmatch = true
o.lazyredraw = true

--  设置缩进宽度
o.sw = 4
--  设置 TAB 宽度
o.ts = 4
-- 禁止展开 tab (noexpandtab)
o.expandtab = false
--  如果后面设置了 expandtab 那么展开 tab 为多少字符
o.softtabstop = 4


o.backup = false
o.writebackup = false
o.undofile = true
o.swapfile = false
o.backupdir = '/tmp/'
o.directory = '/tmp/'
o.undodir = '/tmp/'

--在右边vsplit
o.splitright = true

local cmd = vim.api.nvim_command
cmd('filetype plugin indent on')

-- 设置leader key
U.map('n', '<space>', '<Nop>')
g.mapleader = ' '
g.maplocalleader = ' '
