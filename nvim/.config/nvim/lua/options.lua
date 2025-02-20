local o = vim.o
local g = vim.g
local u = require "util"

-- 自动缩进
o.autoindent = true

-- 打开 C/C++ 语言缩进优化
o.cindent = true
o.nu = true
o.wrap = false
o.termguicolors = true

-- 保留1000个历史文件
-- https://neovim.discourse.group/t/updating-shada-option-in-lua/3324
-- - `!`: Save and restore global variables that start with an uppercase letter, and don't save variables that start with a lowercase letter.
-- - `,'1000`: Save marks for the last 1000 files.
-- - `<50`: Save up to 50 lines from each register.
-- - `s30`: Limit the size of items to 30 KB.
-- - `h`: Disable the 'hlsearch' option when starting up.
vim.o.shada = "!,'1000,<50,s30,h"

o.timeoutlen = 200
o.ttimeout = true
o.ttimeoutlen = 50
o.tags = [[ ./.tags;,.tags ]]

-- 智能搜索大小写判断，默认忽略大小写，除非搜索内容包含大写字母
o.ignorecase = true
o.smartcase = true
-- highlight all matches on previous search pattern
o.hlsearch = true
o.incsearch = true

-- 显示匹配的括号
o.showmatch = true
o.showtabline = 2
o.smartindent = true
o.cmdheight = 1

o.splitright = true
o.splitbelow = true
o.cursorline = true
o.title = true
o.numberwidth = 4
o.colorcolumn = "120"

-- 显示关标位置
o.ruler = true

-- 延迟绘制（提升性能）
o.lazyredraw = true

--  设置缩进宽度
o.sw = 4
--  设置 TAB 宽度
o.ts = 4
-- 禁止展开 tab (noexpandtab)为空格
o.expandtab = true
--  如果后面设置了 expandtab 那么展开 tab 为多少字符
o.softtabstop = 4
o.backup = true
o.writebackup = true
o.undofile = false
o.swapfile = false
o.backupdir = "/tmp/"
o.directory = "/tmp/"
o.undodir = "/tmp/"
o.backupext = ".bak"

--在右边vsplit
o.splitright = true

-- 设置leader key
u.map("n", "<space>", "<Nop>")
g.mapleader = " "
g.maplocalleader = " "

-- 设置分隔符可视
-- o.listchars = "tab:|>-,trail:.,extends:>,precedes:<"
o.listchars = "tab:|  ,trail:.,extends:>,precedes:<"

-- 文件换行符，默认使用 unix 换行符
o.ffs = "unix,dos,mac"

o.suffixes = ".bak,~,.o,.h,.info,.swp,.obj,.pyc,.pyo,.egg-info,.class"
o.jumpoptions = "stack"

vim.api.nvim_create_augroup("wrap_group", {})

local function set_wrap()
  local file_size = vim.fn.getfsize(vim.api.nvim_buf_get_name(0))
  if file_size > 1024 * 1024 then
    vim.wo.wrap = true
  else
    vim.wo.wrap = false
  end
end

vim.api.nvim_create_autocmd("BufRead", {
  pattern = "*",
  group = "wrap_group",
  callback = function()
    set_wrap()
  end,
})

-- global line status
o.laststatus = 3
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
o.wildignore = [[
  .git,.hg,.svn
  *.aux,*.out,*.toc
  *.o,*.obj,*.exe,*.dll,*.manifest,*.rbc,*.class
  *.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp
  *.avi,*.divx,*.mp4,*.webm,*.mov,*.m2ts,*.mkv,*.vob,*.mpg,*.mpeg
  *.mp3,*.oga,*.ogg,*.wav,*.flac
  *.eot,*.otf,*.ttf,*.woff
  *.doc,*.pdf,*.cbr,*.cbz
  *.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.kgb
  *.swp,.lock,.DS_Store,._*
  */tmp/*,*.so,*.swp,*.zip,**/node_modules/**,**/target/**,**.terraform/**"
]]

vim.cmd [[
 set clipboard+=unnamedplus
 set foldcolumn=1
]]

-- https://neovim.discourse.group/t/a-lua-based-auto-refresh-buffers-when-they-change-on-disk-function/2482/3
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = { "*" },
})

--  `"screen"`: 保持屏幕内容在分割窗口时不变。
--  `"topline"`: 保持当前窗口的顶部行在分割窗口时不变。
--  `"cursor"`: 保持光标位置在分割窗口时不变。
--  `"all"`: 保持所有内容在分割窗口时不变。
vim.o.splitkeep = "screen"
