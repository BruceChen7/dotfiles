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

U.map("n", "<space>gg", ":Git <CR>")
U.map("n", "<space>gv", ":Gdiffsplit <CR>")

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

vim.cmd([[
    " CTRL+p 打开文件模糊匹配
    let g:Lf_ShortcutF = '<c-p>'

    " ALT+n 打开 buffer 模糊匹配
    let g:Lf_ShortcutB = '<m-n>'

    " ALT+m 打开最近使用的文件 MRU，进行模糊匹配
    noremap <m-m> :LeaderfMru<cr>

    " ALT+p 打开函数列表，按 i 进入模糊匹配，ESC 退出
    noremap <m-p> :LeaderfFunction<cr>

    " ALT+SHIFT+p 打开 tag 列表，i 进入模糊匹配，ESC退出
    noremap <m-P> :LeaderfBufTag<cr>

    " ALT+n 打开 buffer 列表进行模糊匹配
    noremap <m-n> :LeaderfBuffer<cr>

    " ALT+t 全局 tags 模糊匹配
    noremap <m-t> :LeaderfTag<cr>

    " 最大历史文件保存 2048 个
    let g:Lf_MruMaxFiles = 2048

    " ui 定制
    let g:Lf_StlSeparator = { 'left': '', 'right': '', 'font': '' }

    " 如何识别项目目录，从当前文件目录向父目录递归知道碰到下面的文件/目录
    let g:Lf_RootMarkers = ['.project', '.root', '.svn', '.git']
    let g:Lf_WorkingDirectoryMode = 'Ac'
    let g:Lf_WindowHeight = 0.30
    let g:Lf_CacheDirectory = expand('~/.vim/cache')

    " 显示绝对路径
    let g:Lf_ShowRelativePath = 0
    " 不显示图标
    let g:Lf_ShowDevIcons = 0

    " 隐藏帮助
    let g:Lf_HideHelp = 1

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

    " 使用 ESC 键可以直接退出 leaderf 的 normal 模式
    noremap <space>f :<C-U><C-R>=printf("Leaderf! rg -e %s ", expand("<cword>"))<CR>
]])

vim.cmd([[
	" 设定项目目录标志：除了 .git/.svn 外，还有 .root 文件
	let g:gutentags_project_root = ['.root']
	let g:gutentags_ctags_tagfile = '.tags'

	" 默认生成的数据文件集中到 ~/.cache/tags 避免污染项目目录，好清理
	let g:gutentags_cache_dir = expand('~/.cache/tags')

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
	let g:gutentags_auto_add_gtags_cscope = 1
	let g:gutentags_define_advanced_commands = 1
]])

-- vim-privew
U.map('n', "<m-;>", ":PreviewTag<CR>")
U.map('n', "<m-:", ":PreviewClose<CR>")

vim.cmd([[
"	noremap <m-;> :PreviewTag<CR>
"	noremap <silent><M-:> :PreviewClose<cr>
	function! TermExit(code)
		echom "terminal exit code: ". a:code
	endfunc


	let g:quickui_color_scheme = 'papercol dark'
	let opts = {'w':600, 'h':800, 'callback':'TermExit'}
	let opts.title = 'TIG POP'
	noremap <leader>tg :call quickui#terminal#open('tig', opts)<CR>
]])


vim.cmd([[
	" signify 调优
	let g:signify_vcs_list = ['git', 'svn']
	let g:signify_sign_add               = '+'
	let g:signify_sign_delete            = '_'
	let g:signify_sign_delete_first_line = '‾'
	let g:signify_sign_change            = '~'
	let g:signify_sign_changedelete      = g:signify_sign_change

	" git 仓库使用 histogram 算法进行 diff
	let g:signify_vcs_cmds = {
				\ 'git': 'git diff --no-color --diff-algorithm=histogram --no-ext-diff -U0 -- %f',
				\}
]])

-- AsyncTask
U.map('n', "g1", ":AsyncTask grep-cword<CR>")
