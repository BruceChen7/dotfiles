"======================================================================
"
" keymaps.vim - keymaps start with using <space>
"
" Created by skywind on 2016/10/12
" Last change: 2016/10/12 16:37:25
"
"======================================================================

"----------------------------------------------------------------------
" window control
"----------------------------------------------------------------------
noremap <silent><space>= :resize +3<cr>
 noremap <silent><space>- :resize -3<cr>
noremap <silent><space>, :vertical resize -5<cr>
noremap <silent><space>. :vertical resize +5<cr>

nnoremap <silent><c-w><c-e> :ExpSwitch edit<cr>
nnoremap <silent><c-w>e :ExpSwitch edit<cr>
nnoremap <silent><c-w>m :ExpSwitch vs<cr>
nnoremap <silent><c-w>M :ExpSwitch tabedit<cr>

noremap <silent><space>hh :nohl<cr>
" 将tab标签往左移动
noremap <silent><tab>, :call Tab_MoveLeft()<cr>
noremap <silent><tab>. :call Tab_MoveRight()<cr>
noremap <silent><tab>6 :VinegarOpen leftabove vs<cr>
noremap <silent><tab>7 :VinegarOpen vs<cr>
noremap <silent><tab>8 :VinegarOpen belowright sp<cr>
noremap <silent><tab>9 :VinegarOpen tabedit<cr>
noremap <silent>+ :VinegarOpen edit<cr>

" replace
noremap <space>p viw"0p
noremap <space>y yiw


"----------------------------------------------------------------------
" space + e : vim control
"----------------------------------------------------------------------
noremap <silent><space>eh :call Tools_SwitchSigns()<cr>
noremap <silent><space>en :call Tools_SwitchNumber()<cr>


"----------------------------------------------------------------------
" Movement Enhancement
"----------------------------------------------------------------------
noremap <M-h> b
noremap <M-l> w
noremap <M-j> 10j
noremap <M-k> 10k
noremap <M-J> gj
noremap <M-K> gk
inoremap <M-h> <c-left>
inoremap <M-l> <c-right>
inoremap <M-j> <c-\><c-o>10j
inoremap <M-k> <c-\><c-o>10k
cnoremap <M-h> <c-left>
cnoremap <M-l> <c-right>
cnoremap <M-b> <c-left>
cnoremap <M-f> <c-right>

" editing commands
noremap <space>a ggVG



noremap <silent><F9> :call Toggle_QuickFix(5)<cr>
" noremap <silent><S-F10> :call quickmenu#toggle(0)<cr>
" inoremap <silent><S-F10> <ESC>:call quickmenu#toggle(0)<cr>
" noremap <silent><M-;> :PreviewTag<cr>
noremap <silent><M-:> :PreviewClose<cr>
noremap <silent><tab>; :PreviewGoto edit<cr>
noremap <silent><tab>: :PreviewGoto tabe<cr>

if has('autocmd')
	function! s:quickfix_keymap()
		if &buftype != 'quickfix'
			return
		endif
		nnoremap <silent><buffer> p :PreviewQuickfix<cr>
		nnoremap <silent><buffer> P :PreviewClose<cr>
		setlocal nonumber
	endfunc
	function! s:insert_leave()
		if get(g:, 'echodoc#enable_at_startup') == 0
			set showmode
		endif
	endfunc
	augroup AscQuickfix
		autocmd!
		autocmd FileType qf call s:quickfix_keymap()
		autocmd InsertLeave * call s:insert_leave()
		" autocmd InsertLeave * set showmode
	augroup END
endif

nnoremap <silent><m-a> :PreviewSignature<cr>
inoremap <silent><m-a> <c-\><c-o>:PreviewSignature<cr>


"----------------------------------------------------------------------
" GUI/Terminal
"----------------------------------------------------------------------
noremap <silent><M-[> :call Tools_QuickfixCursor(2)<cr>
noremap <silent><M-]> :call Tools_QuickfixCursor(3)<cr>
noremap <silent><M-{> :call Tools_QuickfixCursor(4)<cr>
noremap <silent><M-}> :call Tools_QuickfixCursor(5)<cr>
noremap <silent><M-u> :call Tools_PreviousCursor(6)<cr>
noremap <silent><M-d> :call Tools_PreviousCursor(7)<cr>

inoremap <silent><M-[> <c-\><c-o>:call Tools_QuickfixCursor(2)<cr>
inoremap <silent><M-]> <c-\><c-o>:call Tools_QuickfixCursor(3)<cr>
inoremap <silent><M-{> <c-\><c-o>:call Tools_QuickfixCursor(4)<cr>
inoremap <silent><M-}> <c-\><c-o>:call Tools_QuickfixCursor(5)<cr>
inoremap <silent><M-u> <c-\><c-o>:call Tools_PreviousCursor(6)<cr>
inoremap <silent><M-d> <c-\><c-o>:call Tools_PreviousCursor(7)<cr>


"----------------------------------------------------------------------
" space + f : open tools
"----------------------------------------------------------------------
" no working
" noremap <silent><space>fd :call Open_Dictionary("<C-R>=expand("<cword>")<cr>")<cr>
" notworking
" noremap <silent><space>fm :!man -S 3:2:1 "<C-R>=expand("<cword>")"<CR>
noremap <silent><space>fh :call Open_HeaderFile(1)<cr>
noremap <silent><space>ft :call Open_Explore(0)<cr>
noremap <silent><space>fe :call Open_Explore(1)<cr>
noremap <silent><space>fo :call Open_Explore(2)<cr>

"----------------------------------------------------------------------
" leader + b/c : buffer
"----------------------------------------------------------------------
noremap <silent><leader>bc :BufferClose<cr>
noremap <silent><leader>cw :call Change_DirectoryToFile()<cr>


let s:filename = expand('<sfile>:p')
exec 'nnoremap <space>hk :FileSwitch tabe '.fnameescape(s:filename).'<cr>'
let s:skywind = fnamemodify(s:filename, ':h:h'). '/skywind.vim'
exec 'nnoremap <space>hs :FileSwitch tabe '.fnameescape(s:skywind).'<cr>'
let s:bundle = fnamemodify(s:filename, ':h:h'). '/bundle.vim'
exec 'nnoremap <space>hv :FileSwitch tabe '.fnameescape(s:bundle).'<cr>'
let s:asclib = fnamemodify(s:filename, ':h:h'). '/autoload/asclib.vim'
exec 'nnoremap <space>hc :FileSwitch tabe '.fnameescape(s:asclib).'<cr>'
let s:auxlib = fnamemodify(s:filename, ':h:h'). '/autoload/auxlib.vim'
exec 'nnoremap <space>hu :FileSwitch tabe '.fnameescape(s:auxlib).'<cr>'
let s:nvimrc = expand("~/.config/nvim/init.vim")
exec 'nnoremap <space>hn :FileSwitch tabe '.fnameescape(s:nvimrc).'<cr>'


"----------------------------------------------------------------------
" space + g : misc
"----------------------------------------------------------------------
"全局的搜索替换跨快捷键
nnoremap <space>gr :%s/\<<C-r><C-w>\>//gc<Left><Left><Left>
nnoremap <space>gq :AsyncStop<cr>
nnoremap <space>gQ :AsyncStop!<cr>
nnoremap <space>gj :%!python -m json.tool<cr>
nnoremap <space>gg :setlocal ts=8 sts=4 sw=4 et<cr>
nnoremap <space>gG :setlocal ts=4 sts=4 sw=4 noet<cr>
nnoremap <silent><space>gf :call Tools_QuickfixCursor(3)<cr>
nnoremap <silent><space>gb :call Tools_QuickfixCursor(2)<cr>

noremap <silent><space>g; :PreviewTag<cr>
noremap <silent><space>g: :PreviewClose<cr>
noremap <silent><space>g' :PreviewGoto edit<cr>
noremap <silent><space>g" :PreviewGoto tabe<cr>

"----------------------------------------------------------------------
" visual mode
"----------------------------------------------------------------------
vnoremap <space>gp :!python<cr>
" vmap <space>gs y/<c-r>"<cr>
vmap <space>gs y/<C-R>=escape(@", '\\/.*$^~[]')<CR>
vmap <space>gr y:%s/<C-R>=escape(@", '\\/.*$^~[]')<CR>//gc<Left><Left><Left>


noremap <C-F10> :VimBuild gcc -pg<cr>


"----------------------------------------------------------------------
" g command
"----------------------------------------------------------------------
nnoremap gb :YcmCompleter GoToDeclaration <cr>
nnoremap gl :YcmCompleter GoToDefinition <cr>
nnoremap gx :YcmCompleter GoToDefinitionElseDeclaration <cr>
nnoremap gy :YcmCompleter GoToReferences <cr>

nnoremap <silent>g1 :AsyncTask grep-cword<cr>
nnoremap <silent>g5 :PreviewTag<cr>
