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

o.ttimeout = true
o.ttimeoutlen = 100
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

o.splitright = true
o.splitbelow = true
o.cursorline = true
o.title = true
o.numberwidth = 4

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

-- 允许代码折叠
o.foldenable = true

-- 代码折叠默认使用缩进
o.fdm = "indent"

-- 默认打开所有缩进
o.foldlevel = 99

--文件搜索和补全时忽略下面扩展名
o.suffixes = ".bak,~,.o,.h,.info,.swp,.obj,.pyc,.pyo,.egg-info,.class"

vim.api.nvim_create_augroup("warp_group", {})

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
  group = "warp_group",
  callback = function()
    set_wrap()
  end,
})

-- global line status
o.laststatus = 3
vim.g.vim_bito_prompt_BitoAiReadable = "现在你是代码专家，开始重构这段代码"

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
 set foldcolumn=0
]]

-- https://neovim.discourse.group/t/a-lua-based-auto-refresh-buffers-when-they-change-on-disk-function/2482/3
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = { "*" },
})
