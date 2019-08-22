set nu
set tabstop=4
" 缩进的空格数
set shiftwidth=4
set expandtab
set tabstop=4
set hlsearch
set cindent
set autoindent
set nowrap
" 补全文件名的时候，忽略这些文件
set wildignore=*.swp,*.bak,*.pyc,*.obj,*.o,*.class
set ttimeout
set ttimeoutlen=100
set cmdheight=1
set ruler
set backspace=2
set magic
set ignorecase
set nocompatible
set nobackup
set incsearch
"set mouse=a
set smartindent
set hlsearch


if has('multi_byte')
	set fileencodings=utf-8,gb2312,gbk,gb18030,big5
	set fenc=utf-8
	set enc=utf-8
endif

"" 在各种模式下都能够移动光标
noremap <C-h> <left>
noremap <C-j> <down>
noremap <C-k> <up>
noremap <C-l> <right>
inoremap <C-h> <left>
inoremap <C-j> <down>
inoremap <C-k> <up>
inoremap <C-l> <right>

" buffer list 快捷键设置
noremap <silent>\bn :bn<cr>
noremap <silent>\bp :bp<cr>
noremap <silent>\bm :bm<cr>
noremap <silent>\bv :vs<cr>
noremap <silent>\bd :bdelete<cr>
noremap <silent>\bl :ls<cr>
noremap <silent>\bb :ls<cr>:b
noremap <silent>\nh :nohl<cr>

" use hotkey to operate tab
noremap <silent><tab> <nop>
noremap <silent><tab>t :tabnew<cr>
noremap <silent><tab>e :tabclose<cr>
noremap <silent><tab>n :tabn<cr>
noremap <silent><tab>p :tabp<cr>
noremap <silent><tab>f <c-i>
noremap <silent><tab>b <c-o>
noremap <silent>\t :tabnew<cr>
noremap <silent>\d :tabclose<cr>
noremap <silent>\1 :tabn 1<cr>
noremap <silent>\2 :tabn 2<cr>
noremap <silent>\3 :tabn 3<cr>
noremap <silent>\4 :tabn 4<cr>
noremap <silent>\5 :tabn 5<cr>
noremap <silent>\6 :tabn 6<cr>
noremap <silent>\7 :tabn 7<cr>
noremap <silent>\8 :tabn 8<cr>
noremap <silent>\9 :tabn 9<cr>
noremap <silent>\0 :tabn 10<cr>
noremap <silent><s-tab> :tabnext<CR>


set scrolloff=2
set showmatch
set display=lastline
set listchars=tab:\|\ ,trail:.,extends:>,precedes:<
set matchtime=3

" window management
noremap <tab>h <c-w>h
noremap <tab>j <c-w>j
noremap <tab>k <c-w>k
noremap <tab>l <c-w>l
noremap <tab>w <c-w>w

"======================================================================
" 配置在insert模式下的设置
"======================================================================
inoremap <tab>h <esc><c-w>h
inoremap <tab>j <esc><c-w>j
inoremap <tab>k <esc><c-w>k
inoremap <tab>l <esc><c-w>l
inoremap <tab>w <esc><c-w>w

"======================================================================
" 这是在terminal模式下使用tab h 来移动光标焦点
"======================================================================
tnoremap <m-q> <c-\><c-n>
if has("terminal") && exists(":terminal") == 2 && has("patch-8.1.1")
    set termwinkey=<c-_>
    tnoremap <tab>h <c-_>h
    tnoremap <tab>l <c-_>l
    tnoremap <tab>j <c-_>j
    tnoremap <tab>k <c-_>k
endif

" insert mode as emacs
inoremap <c-a> <home>
inoremap <c-e> <end>
inoremap <c-d> <del>

" 在命令行的模式的快捷键
cnoremap <c-h> <left>
cnoremap <c-j> <down>
cnoremap <c-k> <up>
cnoremap <c-l> <right>
cnoremap <c-a> <home>
cnoremap <c-e> <end>
cnoremap <c-f> <c-d>
cnoremap <c-b> <left>
cnoremap <c-d> <del>
cnoremap <c-_> <c-k>


let s:home = fnamemodify(resolve(expand('<sfile>:p')), ':h')
command! -nargs=1 IncScript exec 'so '.s:home.'/'.'<args>'
exec 'set rtp+='.s:home

IncScript .vim/asc/vimmake.vim
VimmakeKeymap
IncScript .vim/asc/config.vim
IncScript .vim/asc/tools.vim
IncScript .vim/asc/keymaps.vim
IncScript .vim/asc/plugin.vim
IncScript .vim/asc/misc.vim

syntax  on
filetype plugin  on
filetype plugin indent on

let mapleader = ","

""""""""key mapping""""""""""""""
nnoremap <leader>ev :vsplit ~/.vimrc <cr>
nnoremap <space>s :source ~/.vimrc <cr>
noremap <leader>sp :split<cr>
noremap <leader>v :vsp<CR>
nnoremap W :w!<cr>
nnoremap Q :q!<cr>
inoremap jj <ESC>

""""" Fast Indeting """"""""""
vnoremap < <gv
vnoremap > >gv

set cc=100
colorscheme desert
