"======================================================================
"
" init-plugins.vim -
"
" Created by skywind on 2018/05/31
" Last Modified: 2018/06/10 23:11
"
"======================================================================
" vim: set ts=4 sw=4 tw=78 noet :



"----------------------------------------------------------------------
" 默认情况下的分组，可以再前面覆盖之
"----------------------------------------------------------------------
if !exists('g:bundle_group')
	let g:bundle_group = ['basic', 'tags', 'enhanced', 'filetypes', 'textobj']
	let g:bundle_group += ['tags', 'coc', 'fern']
	let g:bundle_group += ['leaderf']
	let g:bundle_group += ['gist']
endif


"----------------------------------------------------------------------
" 计算当前 vim-init 的子路径
"----------------------------------------------------------------------
let s:home = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')

function! s:path(path)
	let path = expand(s:home . '/' . a:path )
	return substitute(path, '\\', '/', 'g')
endfunc


"----------------------------------------------------------------------
" 在 ~/.vim/bundles 下安装插件
"----------------------------------------------------------------------
call plug#begin(get(g:, 'bundle_home', '~/.vim/bundles'))

let g:plug_url_format = 'https://hub.fastgit.org/%s.git'

"----------------------------------------------------------------------
" 默认插件
"----------------------------------------------------------------------

" 全文快速移动，<leader><leader>f{char} 即可触发
Plug 'easymotion/vim-easymotion'

" 文件浏览器，代替 netrw
Plug 'justinmk/vim-dirvish'

" 表格对齐，使用命令 Tabularize
Plug 'godlygeek/tabular', { 'on': 'Tabularize' }

" Diff 增强，支持 histogram / patience 等更科学的 diff 算法
Plug 'chrisbra/vim-diff-enhanced'

Plug 'ziglang/zig.vim'

"----------------------------------------------------------------------
" Dirvish 设置：自动排序并隐藏文件，同时定位到相关文件
" 这个排序函数可以将目录排在前面，文件排在后面，并且按照字母顺序排序
" 比默认的纯按照字母排序更友好点。
"----------------------------------------------------------------------
function! s:setup_dirvish()
	if &buftype != 'nofile' && &filetype != 'dirvish'
		return
	endif
	if has('nvim')
		return
	endif
	" 取得光标所在行的文本（当前选中的文件名）
	let text = getline('.')
	if ! get(g:, 'dirvish_hide_visible', 0)
		exec 'silent keeppatterns g@\v[\/]\.[^\/]+[\/]?$@d _'
	endif
	" 排序文件名
	exec 'sort ,^.*[\/],'
	let name = '^' . escape(text, '.*[]~\') . '[/*|@=|\\*]\=\%($\|\s\+\)'
	" 定位到之前光标处的文件
	call search(name, 'wc')
	noremap <silent><buffer> ~ :Dirvish ~<cr>
	noremap <buffer> % :e %
endfunc

augroup MyPluginSetup
	autocmd!
	autocmd FileType dirvish call s:setup_dirvish()
augroup END


"----------------------------------------------------------------------
" 基础插件
"----------------------------------------------------------------------
if index(g:bundle_group, 'basic') >= 0
	Plug 'bronson/vim-trailing-whitespace'

	Plug 'Chiel92/vim-autoformat'

	" 一次性安装一大堆 colorscheme
	Plug 'flazz/vim-colorschemes'

	Plug 'sainnhe/everforest'

	" 支持库，给其他插件用的函数库
	Plug 'xolox/vim-misc'

	Plug 'camspiers/lens.vim'

	" 用于在侧边符号栏显示 marks （ma-mz 记录的位置）
	Plug 'kshenoy/vim-signature'

	" 用于在侧边符号栏显示 git/svn 的 diff
	Plug 'mhinz/vim-signify'

	" 根据 quickfix 中匹配到的错误信息，高亮对应文件的错误行
	" 使用 :RemoveErrorMarkers 命令或者 <space>ha 清除错误
	Plug 'mh21/errormarker.vim'

	" 使用 ALT+e 会在不同窗口/标签上显示 A/B/C 等编号，然后字母直接跳转
	Plug 't9md/vim-choosewin'

	" 提供基于 TAGS 的定义预览，函数参数预览，quickfix 预览
	Plug 'skywind3000/vim-preview'
	Plug 'skywind3000/vim-quickui'

	" Git 支持
	Plug 'tpope/vim-fugitive'

	Plug 'ojroques/vim-oscyank', {'branch': 'main'}

	" 用来执行任务
	Plug 'skywind3000/asynctasks.vim'
	Plug 'skywind3000/asyncrun.vim'


	Plug 'skywind3000/Leaderf-snippet'

	Plug 'skywind3000/vim-terminal-help'

	Plug 'SirVer/ultisnips'

	" 用来预览snippet
	Plug 'skywind3000/Leaderf-snippet'
	" 用来设置tab
	Plug 'tpope/vim-sleuth'

	Plug 'mg979/vim-visual-multi', {'branch': 'master'}
	Plug 'machakann/vim-sandwich'
	" 使用 ALT+e 来选择窗口
	nmap <m-e> <Plug>(choosewin)

	"vim-privew调整优化"
	noremap <m-;> :PreviewTag<CR>
	noremap <silent><M-:> :PreviewClose<cr>
	function! TermExit(code)
		echom "terminal exit code: ". a:code
	endfunc


	let g:quickui_color_scheme = 'papercol dark'
	let opts = {'w':600, 'h':800, 'callback':'TermExit'}
	let opts.title = 'TIG POP'
	noremap <leader>tg :call quickui#terminal#open('tig', opts)<CR>
	" 暂时没有啥用
	" noremap <silent><tab>; :PreviewGoto edit<cr>
	" noremap <silent><tab>: :PreviewGoto tabe<cr>

	" 默认不显示 startify
	" let g:startify_disable_at_vimenter = 1
	" let g:startify_session_dir = '~/.vim/session'

	" 使用 <space>ha 清除 errormarker 标注的错误
	noremap <silent><space>ha :RemoveErrorMarkers<cr>

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

	"用来搜索关键字"
	nnoremap <silent>g1 :AsyncTask grep-cword<cr>

	"leaderf-snippet
	let g:UltiSnipsExpandTrigger="<tab>l"
	inoremap <c-x><c-j> <c-\><c-o>:Leaderf snippet<cr>
	" optional: preview
	let g:Lf_PreviewResult = get(g:, 'Lf_PreviewResult', {})
	let g:Lf_PreviewResult.snippet = 1

	" 在vim中操作git
	nnoremap <space>gg :Git<CR>
	nnoremap <space>gv :Gdiffsplit<CR>
endif


"----------------------------------------------------------------------
" 增强插件
"----------------------------------------------------------------------
if index(g:bundle_group, 'enhanced') >= 0

	" 用 v 选中一个区域后，ALT_+/- 按分隔符扩大/缩小选区
	Plug 'terryma/vim-expand-region'

	" 快速文件搜索
	" Plug 'junegunn/fzf'

	" 给不同语言提供字典补全，插入模式下 c-x c-k 触发
	Plug 'asins/vim-dict'


	" 使用 :CtrlSF 命令进行模仿 sublime 的 grep
	Plug 'dyng/ctrlsf.vim'

	" 配对括号和引号自动补全
	Plug 'Raimondi/delimitMate'

	" 提供 gist 接口
	"Plug 'lambdalisue/vim-gista', { 'on': 'Gista' }
	" ALT_+/- 用于按分隔符扩大缩小 v 选区
	map <m-=> <Plug>(expand_region_expand)
	map <m--> <Plug>(expand_region_shrink)
endif


"----------------------------------------------------------------------
" 自动生成 ctags/gtags，并提供自动索引功能
" 不在 git/svn 内的项目，需要在项目根目录 touch 一个空的 .root 文件
" 详细用法见：https://zhuanlan.zhihu.com/p/36279445
"----------------------------------------------------------------------
if index(g:bundle_group, 'tags') >= 0

	" 提供 ctags/gtags 后台数据库自动更新功能
	Plug 'ludovicchabant/vim-gutentags'

	" 提供 GscopeFind 命令并自动处理好 gtags 数据库切换
	" 支持光标移动到符号名上：<leader>cg 查看定义，<leader>cs 查看引用
	Plug 'skywind3000/gutentags_plus'

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

endif


"----------------------------------------------------------------------
" 文本对象：textobj 全家桶
"----------------------------------------------------------------------
if index(g:bundle_group, 'textobj') >= 0

	" 基础插件：提供让用户方便的自定义文本对象的接口
	Plug 'kana/vim-textobj-user'

	" indent 文本对象：ii/ai 表示当前缩进，vii 选中当缩进，cii 改写缩进
	Plug 'kana/vim-textobj-indent'

	" 语法文本对象：iy/ay 基于语法的文本对象
	Plug 'kana/vim-textobj-syntax'

	" 函数文本对象：if/af 支持 c/c++/vim/java
	Plug 'kana/vim-textobj-function', { 'for':['c', 'cpp', 'vim', 'java'] }

	" 参数文本对象：i,/a, 包括参数或者列表元素
	Plug 'sgur/vim-textobj-parameter'

	" 提供 python 相关文本对象，if/af 表示函数，ic/ac 表示类
	Plug 'bps/vim-textobj-python', {'for': 'python'}

	" 提供 uri/url 的文本对象，iu/au 表示
	Plug 'jceb/vim-textobj-uri'
endif


"----------------------------------------------------------------------
" 文件类型扩展
"----------------------------------------------------------------------
if index(g:bundle_group, 'filetypes') >= 0

	" powershell 脚本文件的语法高亮
	" Plug 'pprovost/vim-ps1', { 'for': 'ps1' }

	" lua 语法高亮增强
	Plug 'tbastos/vim-lua', { 'for': 'lua' }

	" C++ 语法高亮增强，支持 11/14/17 标准
	Plug 'octol/vim-cpp-enhanced-highlight', { 'for': ['c', 'cpp'] }

	" 额外语法文件
	Plug 'justinmk/vim-syntax-extra', { 'for': ['c', 'bison', 'flex', 'cpp'] }

	" python 语法文件增强
	Plug 'vim-python/python-syntax', { 'for': ['python'] }

	" rust 语法增强
	Plug 'rust-lang/rust.vim', { 'for': 'rust' }

	" vim org-mode
	" Plug 'jceb/vim-orgmode', { 'for': 'org' }
endif


"----------------------------------------------------------------------
" airline
"----------------------------------------------------------------------
if index(g:bundle_group, 'airline') >= 0
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
	let g:airline_left_sep = ''
	let g:airline_left_alt_sep = ''
	let g:airline_right_sep = ''
	let g:airline_right_alt_sep = ''
	let g:airline_powerline_fonts = 0
	let g:airline_exclude_preview = 1
	let g:airline_section_b = '%n'
	let g:airline_theme='deus'
	let g:airline#extensions#branch#enabled = 0
	let g:airline#extensions#syntastic#enabled = 0
	let g:airline#extensions#fugitiveline#enabled = 0
	let g:airline#extensions#csv#enabled = 0
	let g:airline#extensions#vimagit#enabled = 0
endif


"----------------------------------------------------------------------
"ranger
"----------------------------------------------------------------------
if index(g:bundle_group, 'ranger') >= 0
	" https://github.com/francoiscabrol/ranger.vim
	Plug 'francoiscabrol/ranger.vim'
	let g:ranger_map_keys = 0
	map nc :Ranger<CR>
	map ne :RangerWorkingDirectory<CR>

endif

"----------------------------------------------------------------------
" fern
"----------------------------------------------------------------------
if index(g:bundle_group, 'fern') >= 0
	Plug 'lambdalisue/fern.vim'
	function! s:init_fern() abort
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
		autocmd FileType fern call s:init_fern()
	augroup END

	Plug 'yuki-yano/fern-preview.vim'

endif
"----------------------------------------------------------------------
" LanguageTool 语法检查
"----------------------------------------------------------------------
if index(g:bundle_group, 'grammer') >= 0
	Plug 'rhysd/vim-grammarous'
	noremap <space>rg :GrammarousCheck --lang=en-US --no-move-to-first-error --no-preview<cr>
	map <space>rr <Plug>(grammarous-open-info-window)
	map <space>rv <Plug>(grammarous-move-to-info-window)
	map <space>rs <Plug>(grammarous-reset)
	map <space>rx <Plug>(grammarous-close-info-window)
	map <space>rm <Plug>(grammarous-remove-error)
	map <space>rd <Plug>(grammarous-disable-rule)
	map <space>rn <Plug>(grammarous-move-to-next-error)
	map <space>rp <Plug>(grammarous-move-to-previous-error)
endif


"----------------------------------------------------------------------
" ale：动态语法检查
"----------------------------------------------------------------------
if index(g:bundle_group, 'ale') >= 0
	Plug 'w0rp/ale'

	" 设定延迟和提示信息
	let g:ale_completion_delay = 500
	let g:ale_echo_delay = 20
	let g:ale_lint_delay = 500
	let g:ale_echo_msg_format = '[%linter%] %code: %%s'

	" 设定检测的时机：normal 模式文字改变，或者离开 insert模式
	" 禁用默认 INSERT 模式下改变文字也触发的设置，太频繁外，还会让补全窗闪烁
	let g:ale_lint_on_text_changed = 'normal'
	let g:ale_lint_on_insert_leave = 1

	" 在 linux/mac 下降低语法检查程序的进程优先级（不要卡到前台进程）
	if has('win32') == 0 && has('win64') == 0 && has('win32unix') == 0
		let g:ale_command_wrapper = 'nice -n5'
	endif

	" 允许 airline 集成
	let g:airline#extensions#ale#enabled = 1

	" 编辑不同文件类型需要的语法检查器
	let g:ale_linters = {
				\ 'c': ['gcc', 'cppcheck'],
				\ 'cpp': ['gcc', 'cppcheck'],
				\ 'python': ['flake8', 'pylint'],
				\ 'lua': ['luac'],
				\ 'go': ['go build', 'gofmt'],
				\ 'java': ['javac'],
				\ 'javascript': ['eslint'],
				\ }


	" 获取 pylint, flake8 的配置文件，在 vim-init/tools/conf 下面
	function s:lintcfg(name)
		let conf = s:path('tools/conf/')
		let path1 = conf . a:name
		let path2 = expand('~/.vim/linter/'. a:name)
		if filereadable(path2)
			return path2
		endif
		return shellescape(filereadable(path2)? path2 : path1)
	endfunc

	" 设置 flake8/pylint 的参数
	let g:ale_python_flake8_options = '--conf='.s:lintcfg('flake8.conf')
	let g:ale_python_pylint_options = '--rcfile='.s:lintcfg('pylint.conf')
	let g:ale_python_pylint_options .= ' --disable=W'
	let g:ale_c_gcc_options = '-Wall -O2 -std=c99'
	let g:ale_cpp_gcc_options = '-Wall -O2 -std=c++14'
	let g:ale_c_cppcheck_options = ''
	let g:ale_cpp_cppcheck_options = ''

	let g:ale_linters.text = ['textlint', 'write-good', 'languagetool']

	" 如果没有 gcc 只有 clang 时（FreeBSD）
	if executable('gcc') == 0 && executable('clang')
		let g:ale_linters.c += ['clang']
		let g:ale_linters.cpp += ['clang']
	endif
endif


"----------------------------------------------------------------------
" echodoc：搭配 YCM/deoplete 在底部显示函数参数
"----------------------------------------------------------------------
if index(g:bundle_group, 'echodoc') >= 0
	Plug 'Shougo/echodoc.vim'
	set noshowmode
	let g:echodoc#enable_at_startup = 1
endif

"----------------------------------------------------------------------
" coc-nvim：用来进行代码补全
"----------------------------------------------------------------------
if index(g:bundle_group, 'coc') >= 0
	Plug 'neoclide/coc.nvim', {'branch': 'release'}
	set updatetime=200
	set shortmess+=c
	set cmdheight=2
	" Recently vim can merge signcolumn and number column into one
	set signcolumn=number

	" Use tab for trigger completion with characters ahead and navigate.
	" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
	" other plugin before putting this into your config.
	inoremap <silent><expr> <TAB>
				\ pumvisible() ? "\<C-n>" :
				\ <SID>check_back_space() ? "\<TAB>" :
				\ coc#refresh()
	inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

	function! s:check_back_space() abort
		let col = col('.') - 1
		return !col || getline('.')[col - 1]  =~# '\s'
	endfunction

	" Make <CR> auto-select the first completion item and notify coc.nvim to
	" format on enter, <cr> could be remapped by other vim plugin
	inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
				\: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

	" Use `[g` and `]g` to navigate diagnostics
	" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
	nmap <silent> [g <Plug>(coc-diagnostic-prev)
	nmap <silent> ]g <Plug>(coc-diagnostic-next)

	" GoTo code navigation.
	nmap <silent> gd <Plug>(coc-definition)
	nmap <silent> gy <Plug>(coc-type-definition)
	nmap <silent> gi <Plug>(coc-implementation)
	nmap <silent> gr <Plug>(coc-references)


	function! s:show_documentation()
		if (index(['vim','help'], &filetype) >= 0)
			execute 'h '.expand('<cword>')
		elseif (coc#rpc#ready())
			call CocActionAsync('doHover')
		else
			execute '!' . &keywordprg . " " . expand('<cword>')
		endif
	endfunction

	"Highlight the symbol and its references when holding the cursor.
	autocmd CursorHold * silent call CocActionAsync('highlight')

endif

if index(g:bundle_group, 'vaffle') >= 0
	Plug 'cocopon/vaffle.vim'
	let g:vaffle_show_hidden_files=1
	nnoremap ne :Vaffle <cr>
	nnoremap nc :Vaffle %:h <cr>

	function! s:customize_vaffle_mappings() abort
		" Customize key mappings here
		" ~
		nmap <buffer><Bslash>  <Plug>(vaffle-open-root)
		nmap <buffer> m        <Plug>(vaffle-mkdir)
		nmap <buffer> a        <Plug>(vaffle-new-file)
		nmap <buffer> u        <Plug>(vaffle-open-parent)
		nmap <buffer> o        <Plug>(vaffle-open-selected)
	endfunction
	augroup vimrc_vaffle
		autocmd!
		autocmd FileType vaffle call s:customize_vaffle_mappings()
	augroup END
endif
"----------------------------------------------------------------------
" LeaderF：CtrlP / FZF 的超级代替者，文件模糊匹配，tags/函数名 选择
"----------------------------------------------------------------------
if index(g:bundle_group, 'leaderf') >= 0
	" 如果 vim 支持 python 则启用  Leaderf
	if has('python') || has('python3')
		Plug 'Yggdroot/LeaderF'

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
		let g:Lf_NormalMap = {
					\ "File":   [["<ESC>", ':exec g:Lf_py "fileExplManager.quit()"<CR>']],
					\ "Buffer": [["<ESC>", ':exec g:Lf_py "bufExplManager.quit()"<cr>']],
					\ "Mru": [["<ESC>", ':exec g:Lf_py "mruExplManager.quit()"<cr>']],
					\ "Tag": [["<ESC>", ':exec g:Lf_py "tagExplManager.quit()"<cr>']],
					\ "BufTag": [["<ESC>", ':exec g:Lf_py "bufTagExplManager.quit()"<cr>']],
					\ "Function": [["<ESC>", ':exec g:Lf_py "functionExplManager.quit()"<cr>']],
					\ }
		noremap <space>f :<C-U><C-R>=printf("Leaderf! rg -e %s ", expand("<cword>"))<CR>
	endif
endif

if index(g:bundle_group, "gist") >= 0
	Plug 'mattn/webapi-vim'
	Plug 'mattn/vim-gist'
	let g:gist_show_privates = 1
	let g:gist_post_private = 1
	nnoremap <leader>gsl :Gist -l <CR>
	nnoremap <leader>gsp :Gist -b <CR>
	nnoremap <leader>gsd :Gist -d <CR>
endif
"----------------------------------------------------------------------
" 结束插件安装
"----------------------------------------------------------------------
call plug#end()
