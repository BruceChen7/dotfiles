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

-- fern.vim
vim.cmd([[
    function! InitFern() abort
        " Define NERDTree like mappings
        nmap <buffer> o <Plug>(fern-action-open:edit)
        nmap <buffer> go <Plug>(fern-action-open:edit)<C-w>p
        nmap <buffer> t <Plug>(fern-action-open:tabedit)
        nmap <buffer> T <Plug>(fern-action-open:tabedit)gT
        nmap <buffer> i <Plug>(fern-action-open:split)
        nmap <buffer> gi <Plug>(fern-action-open:split)<C-w>p
        nmap <buffer> s <Plug>(fern-action-open:vsplit)
        nmap <buffer> gs <Plug>(fern-action-open:vsplit)<C-w>p
        nmap <buffer> ma <Plug>(fern-action-new-path)
        nmap <buffer> P gg
        nmap <buffer> as <Plug>(fern-action-open:select)

        nmap <buffer> C <Plug>(fern-action-enter)
        nmap <buffer> u <Plug>(fern-action-leave)
        nmap <buffer> r <Plug>(fern-action-reload)
        nmap <buffer> R gg<Plug>(fern-action-reload)<C-o>
        nmap <buffer> cd <Plug>(fern-action-cd)
        nmap <buffer> CD gg<Plug>(fern-action-cd)<C-o>

        nmap <buffer> I <Plug>(fern-action-hidden)

        nmap <buffer> q :<C-u>quit<CR>
    endfunction

    noremap ne :Fern .  -reveal=% <CR>
    noremap nE :Fern . -opener=vsplit -reveal=% <CR>
    " noremap nc :Fern %:h -drawer -reveal=% -toggle <CR>
    " current buffer directory
    noremap nc :Fern %:h  -reveal=% <CR>
    noremap nC :Fern %:h -opener=vsplit -reveal=% <CR>

    augroup fern-custom
       autocmd! *
       autocmd FileType fern call InitFern()
    augroup END

]])

-- leaderf config
-- CTRL+p 打开文件模糊匹配
vim.g.Lf_ShortcutF = '<C-p>'
-- ALT+n 打开 buffer 模糊匹配
vim.g.Lf_ShortcutB = '<m-n>'
-- " 显示绝对路径
vim.g.Lf_ShowRelativePath = 0
-- " 不显示图标
vim.g.Lf_ShowDevIcons = 1
-- " 隐藏帮助
vim.g.Lf_HideHelp = 0

vim.g.Lf_MruMaxFiles = 2048
-- " 如何识别项目目录，从当前文件目录向父目录递归知道碰到下面的文件/目录
-- vim.g.Lf_RootMarkers = [[ '.project', '.root', '.svn', '.git']]
vim.g.Lf_WorkingDirectoryMode = 'Ac'
vim.g.Lf_WindowHeight = 0.40
vim.g.Lf_CacheDirectory = vim.fn.expand('~/.vim/cache')

-- ALT+m 打开最近使用的文件 MRU，进行模糊匹配
U.map('n', '<m-m>', ':LeaderfMru<cr>')
U.map('n', '<m-p>', ':LeaderfFunction<cr>')
-- " ALT+SHIFT+p 打开 tag 列表，i 进入模糊匹配，ESC退出
U.map('n', '<m-P>', ':LeaderfBufTag<cr>')
-- ALT+n 打开 buffer 列表进行模糊匹配
U.map('n', '<m-n>', ':LeaderfBuffer<cr>')
-- " ALT+t 全局 tags 模糊匹配
U.map('n', '<m-t>', ':LeaderfTag<cr>')

--U.map('n', '<space>f', ':<C-U><C-R>=printf("Leaderf! rg -e %s", expand("<cword>"))<CR>')

vim.cmd([[
    " ui 定制
    let g:Lf_StlSeparator = { 'left': '', 'right': '', 'font': '' }

    " 如何识别项目目录，从当前文件目录向父目录递归知道碰到下面的文件/目录
    let g:Lf_RootMarkers = ['.project', '.root', '.svn', '.git']

    " 模糊匹配忽略扩展名
    let g:Lf_WildIgnore = {
                \ 'dir': ['.svn','.git','.hg'],
                \ 'file': ['*.sw?','~$*','*.bak','*.exe','*.o','*.so','*.py[co]']
                \ }

    " MRU 文件忽略扩展名
    let g:Lf_MruFileExclude = ['*.so', '*.exe', '*.py[co]', '*.sw?', '~$*', '*.bak', '*.tmp', '*.dll']
    let g:Lf_StlColorscheme = 'powerline'

    " 禁用 function/buftag 的预览功能，可以手动用 p 预览
    let g:Lf_PreviewResult = {'Function':0, 'BufTag':0}
    noremap <space>f :<C-U><C-R>=printf("Leaderf! rg -e %s ", expand("<cword>"))<CR>
]])

vim.g.gutentags_project_root = {'.root'}
vim.g.gutentags_ctags_tagfile = '.tags'
vim.g.gutentags_cache_dir = vim.fn.expand('~/.cache/tags')

if vim.fn.executable('ctags') then
	vim.g["gutentags_modules"] = {}
	local m = vim.g["gutentags_modules"]
	print(vim.inspect(#m))
	m[#m+1] = 'ctags'
	print(vim.inspect(vim.g["gutentags_modules"]))
end

vim.cmd([[
	" 设定项目目录标志：除了 .git/.svn 外，还有 .root 文件

	" 默认禁用自动生成
	let g:gutentags_modules = []

	" 如果有 ctags 可执行就允许动态生成 ctags 文件
	if executable('ctags')
		let g:gutentags_modules += ['ctags']
	endif

	" 如果有 gtags 可执行就允许动态生成 gtags 数据库
	if executable('gtags') && executable('gtags-cscope')
		let g:gutentags_modules += ['gtags_cscope']
		let $GTAGSLABEL = 'native-pygments'
		let $GTAGSLABEL = 'native'
		if has("macunix")
			let $GTAGSCONF='/usr/local/share/gtags/gtags.conf'
		elseif has("unix")
			let $GTAGSCONF='/usr/share/gtags/gtags.conf'
		endif
	endif

	" 设置 ctags 的参数
	let g:gutentags_ctags_extra_args = []
	let g:gutentags_ctags_extra_args = ['--fields=+niazS', '--extras=+q']
	let g:gutentags_ctags_extra_args += ['--c++-kinds=+px']
	let g:gutentags_ctags_extra_args += ['--c-kinds=+px']

	" 使用 universal-ctags 的话需要下面这行，请反注释
	let g:gutentags_ctags_extra_args += ['--output-format=e-ctags']

	" 禁止 gutentags 自动链接 gtags 数据库
	let g:gutentags_auto_add_gtags_cscope = 0
	let g:gutentags_define_advanced_commands = 1
]])

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

--  signify sign config
vim.g.signify_sign_add = '+'
vim.g.signify_sign_delete = '-'
vim.g.signify_sign_change = '~'
vim.g.signify_sign_delete_first_line = '‾'
vim.g.signify_sign_changedelete = vim.g.signify_sign_change
vim.g.signify_vcs_list = {'git', 'svn'}
vim.cmd([[

	" git 仓库使用 histogram 算法进行 diff
	let g:signify_vcs_cmds = {
				\ 'git': 'git diff --no-color --diff-algorithm=histogram --no-ext-diff -U0 -- %f',
				\}
]])

-- AsyncTask
U.map('n', "g1", ":AsyncTask grep-cword<CR>")

-- indent-files
vim.g.indent_blankline_char = '┊'
vim.g.indent_blankline_filetype_exclude = { 'help', 'packer' }
vim.g.indent_blankline_buftype_exclude = { 'terminal', 'nofile' }
vim.g.indent_blankline_char_highlight = 'LineNr'
vim.g.indent_blankline_show_trailing_blankline_indent = false

-- 自动打开 quickfix window ，高度为 6
vim.g.asyncrun_open = 10
-- 任务结束时候响铃提醒
vim.g.asyncrun_bell = 1

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
