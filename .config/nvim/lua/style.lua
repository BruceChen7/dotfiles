local o = vim.opt
-- 总是显示标签栏
--o.showtabline
-- 设置显示制表符等隐藏字符
o.list = true
-- 右边显示命令
o.showcmd = true
-- 显示行号
o.number = true

o.splitright = true

o.showtabline = 2
--o.errorformat = vim.opt.errorformat + '%f|%l col %c|%m'
o.errorformat:append('[%f:%l] -> %m,[%f:%l]:%m')

-- 设置buffer
-- TODO: 重写这部分代码
vim.cmd([[
	highlight clear SignColumn
	"quickfix 设置，隐藏行号
	augroup VimInitStyle
		au!
		au FileType qf setlocal nonumber
	augroup END

	" 修正补全目录的色彩：默认太难看
	hi! Pmenu guibg=gray guifg=black ctermbg=gray ctermfg=black
	hi! PmenuSel guibg=gray guifg=brown ctermbg=brown ctermfg=gray

	"----------------------------------------------------------------------
	" 需要显示到标签上的文件名
	"----------------------------------------------------------------------
	function! VimNeatBuffer(bufnr, fullname)
		let l:name = bufname(a:bufnr)
		if getbufvar(a:bufnr, '&modifiable')
			if l:name == ''
				return '[No Name]'
			else
				if a:fullname
					return fnamemodify(l:name, ':p')
				else
					let aname = fnamemodify(l:name, ':p')
					let sname = fnamemodify(aname, ':t')
					if sname == ''
						let test = fnamemodify(aname, ':h:t')
						if test != ''
							return '<'. test . '>'
						endif
					endif
					return sname
				endif
			endif
		else
			let l:buftype = getbufvar(a:bufnr, '&buftype')
			if l:buftype == 'quickfix'
				return '[Quickfix]'
			elseif l:name != ''
				if a:fullname
					return '-'.fnamemodify(l:name, ':p')
				else
					return '-'.fnamemodify(l:name, ':t')
				endif
			else
			endif
			return '[No Name]'
		endif
	endfunc


	"----------------------------------------------------------------------
	" 标签栏文字，使用 [1] filename 的模式
	"----------------------------------------------------------------------
	function! VimNeatTabLabel(n)
		let l:buflist = tabpagebuflist(a:n)
		let l:winnr = tabpagewinnr(a:n)
		let l:bufnr = l:buflist[l:winnr - 1]
		let l:fname = VimNeatBuffer(l:bufnr, 0)
		let l:num = a:n
		let style = get(g:, 'config_vim_tab_style', 0)
		if style == 0
			return l:fname
		elseif style == 1
			return "[".l:num."] ".l:fname
		elseif style == 2
			return "".l:num." - ".l:fname
		endif
		if getbufvar(l:bufnr, '&modified')
			return "[".l:num."] ".l:fname." +"
		endif
		return "[".l:num."] ".l:fname
	endfunc

	"----------------------------------------------------------------------
	" 终端下的 tabline
	"----------------------------------------------------------------------
	function! VimNeatTabLine()
		let s = ''
		for i in range(tabpagenr('$'))
			" select the highlighting
			if i + 1 == tabpagenr()
				let s .= '%#TabLineSel#'
			else
				let s .= '%#TabLine#'
			endif

			" set the tab page number (for mouse clicks)
			let s .= '%' . (i + 1) . 'T'

			" the label is made by MyTabLabel()
			let s .= ' %{VimNeatTabLabel(' . (i + 1) . ')} '
		endfor

		" after the last tab fill with TabLineFill and reset tab page nr
		let s .= '%#TabLineFill#%T'

		" right-align the label to close the current tab page
		if tabpagenr('$') > 1
			let s .= '%=%#TabLine#%999XX'
		endif

		return s
	endfunc

	set tabline=%!VimNeatTabLine()
]])

vim.cmd([[
augroup InitFileTypesGroup

	" 清除同组的历史 autocommand
	au!

	" C/C++ 文件使用 // 作为注释
	au FileType c,cpp setlocal commentstring=//\ %s

	au FileType zig setlocal ts=4 sw=4 et
	" markdown 允许自动换行
	au FileType markdown setlocal wrap

	" lisp 进行微调
	au FileType lisp setlocal ts=8 sts=2 sw=2 et

	au FileType go setlocal ts=8 sw=8 et

	au FileType lua setlocal ts=4 sw=4 et

	" scala 微调
	au FileType scala setlocal sts=4 sw=4 noet

	" haskell 进行微调
	au FileType haskell setlocal et

	" quickfix 隐藏行号
	"au FileType qf setlocal nonumber
	autocmd FileType qf nnoremap <silent><buffer> p :PreviewQuickfix<cr>
	autocmd FileType qf nnoremap <silent><buffer> P :PreviewClose<cr>

	" 强制对某些扩展名的 filetype 进行纠正
	au BufNewFile,BufRead *.as setlocal filetype=actionscript
	au BufNewFile,BufRead *.pro setlocal filetype=prolog
	au BufNewFile,BufRead *.es setlocal filetype=erlang
	au BufNewFile,BufRead *.asc setlocal filetype=asciidoc
	au BufNewFile,BufRead *.vl setlocal filetype=verilog
augroup END
]])

function getColorscheme()
	local colorschemes = {"vscode", "nvcode"}
	local u = require('util')
	local len = u.tableLength(colorschemes)
	i = U.random(len)
	scheme = colorschemes[i]

	if scheme == 'vscode' then
		vim.g.vscode_style ='dark'
	end
	return scheme
end


vim.cmd([[
	let scheme = v:lua.getColorscheme()
	execute 'colorscheme ' . scheme
]])


function status_encoding()
    if vim.o.fenc ~= "" then
        code = vim.o.fenc
    else
        code = vim.o.enc
    end
    if vim.o.bomb then
        code = code .. ",BOM"
    end
    return code
end

-- help statusline
function status_line()
    file_name = "%F "
    git_status = "%{fugitive#statusline()}"
    buffer_status = "[%1*%M%*%n%R%H]" -- [buffer number and buffer status]
    -- 右对齐
    seg = "%="
    file_type = "%y " -- lua/go/rust

    print(code)
    -- " 最右边显示文件编码和行号等信息，并且固定在一个 group 中，优先占位
    file_encoding = "%0(%{&fileformat} [%{v:lua.status_encoding()}] %v:%l/%L%) "
    res = file_name..git_status..buffer_status..seg..file_type..file_encoding
    return res
end

vim.o.statusline = status_line()
