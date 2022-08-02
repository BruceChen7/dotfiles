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
o.errorformat:append "[%f:%l] -> %m,[%f:%l]:%m"

o.relativenumber = false
o.mouse = "n"


vim.cmd [[
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

	au FileType proto setlocal ts=2 sw=2
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
]]

function getColorscheme()
  local colorschemes = { --"vscode",
    "nightfox",
    "dayfox",
    "nordfox",
    "duskfox",
    "terafox",
  }
  local u = require "util"
  local len = u.tableLength(colorschemes)
  i = u.random(len)
  scheme = colorschemes[i]

  if scheme == "vscode" then
    vim.g.vscode_style = "dark"
  end
  return scheme
end

vim.cmd [[
	let scheme = v:lua.getColorscheme()
	execute 'colorscheme ' . scheme
]]
