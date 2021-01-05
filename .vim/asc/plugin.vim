silent! call plug#begin()
Plug 'scrooloose/nerdtree'
Plug 'tomtom/tcomment_vim'
Plug 'skywind3000/asynctasks.vim'
Plug 'skywind3000/asyncrun.vim'
Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'bronson/vim-trailing-whitespace'
Plug 'Yggdroot/LeaderF', {'do': './install.sh'}
Plug 'mhinz/vim-signify'
Plug 'ludovicchabant/vim-gutentags'
Plug 'skywind3000/vim-preview'
Plug 'skywind3000/gutentags_plus'
Plug 'tpope/vim-fugitive'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'Chiel92/vim-autoformat'
Plug 'wellle/targets.vim'
Plug 'pechorin/any-jump.vim'
Plug 'voldikss/vim-floaterm'
Plug 'camspiers/lens.vim'
Plug 'ojroques/vim-oscyank', {'branch': 'main'}

" colorscheme
Plug 'kkga/vim-envy'
Plug 'sonph/onehalf', { 'rtp': 'vim' }
Plug 'habamax/vim-polar'
call plug#end()


"----------------------------------------------------------------------
" nerdtree setting
"----------------------------------------------------------------------
let NERDTreeWinSize=20
noremap ne :NERDTreeToggle<CR> :vertical resize +3 <cr>
noremap nc :NERDTree % <CR>
let NERDTreeIgnore = ['\~$', '\$.*$', '\.swp$', '\.pyc$', '#.\{-\}#$']
let NERDTreeRespectWildIgnore = 1
" noremap <silent> nc :Fern %:h -drawer -width=35 -toggle<CR><C-w>=
" noremap <silent> ne :Fern . -reveal=% <CR><C-w>=


"----------------------------------------------------------------------
" Youcompleteme setting
"----------------------------------------------------------------------
" let g:ycm_add_preview_to_completeopt = 0
" let g:ycm_show_diagnostics_ui = 0
" let g:ycm_server_log_level = 'info'
" let g:ycm_min_num_identifier_candidate_chars = 2
" let g:ycm_collect_identifiers_from_comments_and_strings = 1
" let g:ycm_complete_in_strings=1
" let g:ycm_key_invoke_completion = '<c-z>'
" let g:ycm_complete_in_comments = 1
" set completeopt=menu,menuone
" let g:ycm_global_ycm_extra_conf = '~/.vim/plugged/YouCompleteMe/third_party/ycmd/.ycm_extra_conf.py'
"
" noremap <c-z> <NOP>
"
" let g:ycm_semantic_triggers =  {
" 			\ 'c,cpp,python,java,go,erlang,perl': ['re!\w{2}'],
" 			\ 'cs,lua,javascript': ['re!\w{2}'],
" 			\ }
"
" let g:ycm_server_python_interpreter="/usr/bin/python3"
" let g:ycm_filetype_whitelist = {
" 			\ "c":1,
" 			\ "cpp":1,
" 			\ "objc":1,
" 			\ "objcpp":1,
" 			\ "python":1,
" 			\ "java":1,
" 			\ "javascript":1,
" 			\ "coffee":1,
" 			\ "vim":1,
" 			\ "go":1,
" 			\ "cs":1,
" 			\ "lua":1,
" 			\ "perl":1,
" 			\ "perl6":1,
" 			\ "php":1,
" 			\ "ruby":1,
" 			\ "rust":1,
" 			\ "erlang":1,
" 			\ "asm":1,
" 			\ "nasm":1,
" 			\ "masm":1,
" 			\ "tasm":1,
" 			\ "asm68k":1,
" 			\ "asmh8300":1,
" 			\ "asciidoc":1,
" 			\ "basic":1,
" 			\ "vb":1,
" 			\ "make":1,
" 			\ "cmake":1,
" 			\ "html":1,
" 			\ "css":1,
" 			\ "less":1,
" 			\ "json":1,
" 			\ "cson":1,
" 			\ "typedscript":1,
" 			\ "haskell":1,
" 			\ "lhaskell":1,
" 			\ "lisp":1,
" 			\ "scheme":1,
" 			\ "sdl":1,
" 			\ "sh":1,
" 			\ "zsh":1,
" 			\ "bash":1,
" 			\ "man":1,
" 			\ "markdown":1,
" 			\ "matlab":1,
" 			\ "maxima":1,
" 			\ "dosini":1,
" 			\ "conf":1,
" 			\ "config":1,
" 			\ "zimbu":1,
" 			\ "ps1":1,
" 			\ }

" leadf设置
let g:Lf_ShortcutF = '<c-p>'
noremap <m-m> :LeaderfMru<cr>
noremap <m-p> :LeaderfFunction<cr>
noremap <m-b> :LeaderfBuffer<cr>
noremap <m-t> :LeaderfTag<cr>

" vim-preivew设置
noremap <m-;> :PreviewTag<CR>
noremap <silent><M-:> :PreviewClose<cr>
noremap <silent><tab>; :PreviewGoto edit<cr>
noremap <silent><tab>: :PreviewGoto tabe<cr>


" signify设置
" noremap <s-l> :SignifyDiff<cr>

let g:Lf_StlSeparator = { 'left': '', 'right': '', 'font': '' }
let g:Lf_RootMarkers = ['.project', '.root', '.svn', '.git']
let g:Lf_WorkingDirectoryMode = 'Ac'
let g:Lf_WindowHeight = 0.30
let g:Lf_CacheDirectory = expand('~/.vim/cache')
let g:Lf_ShowRelativePath = 0
let g:Lf_HideHelp = 1
let g:Lf_StlColorscheme = 'powerline'
let g:Lf_Ctags = '/usr/local/bin/ctags'

let g:Lf_NormalMap = {
			\ "File":   [["<ESC>", ':exec g:Lf_py "fileExplManager.quit()"<CR>'],
			\            ["<F6>", ':exec g:Lf_py "fileExplManager.quit()"<CR>'] ],
			\ "Buffer": [["<ESC>", ':exec g:Lf_py "bufExplManager.quit()"<CR>'],
			\            ["<F6>", ':exec g:Lf_py "bufExplManager.quit()"<CR>'] ],
			\ "Mru":    [["<ESC>", ':exec g:Lf_py "mruExplManager.quit()"<CR>']],
			\ "Tag":    [["<ESC>", ':exec g:Lf_py "tagExplManager.quit()"<CR>']],
			\ "Function":    [["<ESC>", ':exec g:Lf_py "functionExplManager.quit()"<CR>']],
			\ "Colorscheme":    [["<ESC>", ':exec g:Lf_py "colorschemeExplManager.quit()"<CR>']],
			\ }

" tags设置
set tags=./.tags;,.tags

let g:gutentags_modules = ['ctags', 'gtags_cscope']
" gutentags 搜索工程目录的标志，碰到这些文件/目录名就停止向上一级目录递归
let g:gutentags_project_root = ['.root', '.svn', '.git', '.hg', '.project']
" 所生成的数据文件的名称
let g:gutentags_ctags_tagfile = '.tags'
" 将自动生成的 tags 文件全部放入 ~/.cache/tags 目录中，避免污染工程目录
let s:vim_tags = expand('~/.cache/tags')
" 设置目录
let g:gutentags_cache_dir = s:vim_tags

" change focus to quickfix window after search (optional).
let g:gutentags_plus_switch = 1


" 配置 ctags/universal tags 的参数
let g:gutentags_ctags_extra_args = ['--fields=+niazS', '--extra=+q']
let g:gutentags_ctags_extra_args += ['--c++-kinds=+px']
let g:gutentags_ctags_extra_args += ['--c-kinds=+px']
" 使用universal ctags
let g:gutentags_ctags_extra_args += ['--output-format=e-ctags']
" 不加载universal ctags数据库
let g:gutentags_auto_add_gtags_cscope = 0

let g:gutentags_define_advanced_commands = 1
let $GTAGSLABEL='native'
let $GTAGSCONF='/usr/share/gtags/gtags.conf'


" 检测 ~/.cache/tags 不存在就新建
if !isdirectory(s:vim_tags)
	silent! call mkdir(s:vim_tags, 'p')
endif

let g:asyncrun_open = 6

"""coc.vims配置
set updatetime=300
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
