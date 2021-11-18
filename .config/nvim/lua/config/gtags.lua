vim.g.gutentags_project_root = {'.root'}
vim.g.gutentags_ctags_tagfile = '.tags'
vim.g.gutentags_cache_dir = vim.fn.expand('~/.cache/tags')
-- 禁止 gutentags 自动链接 gtags 数据库
vim.g.gutentags_auto_add_gtags_cscope = 0
vim.g.gutentags_define_advanced_commands = 0

-- vim.g.gutentags_ctags_extra_args = {'--fields=+niazS', '--extras=+q', '--c++-kinds=+px', '--c-kinds=+px'}
-- 使用 universal-ctags 的话需要下面这行，请反注释
local extra_tags =  {'--fields=+niazS', '--extras=+q', '--c++-kinds=+px', '--c-kinds=+px'}
table.insert(extra_tags, '--output-format=e-ctags')
vim.g.gutentags_ctags_extra_args = extra_tags

local modules = {}
if vim.fn.executable('ctags') then
	table.insert(modules, 'ctags')
	if vim.fn.executable('gtags') and vim.fn.executable('gtags-cscope') then
		table.insert(modules, 'gtags_cscope')
	end
end
vim.g.gutentags_modules = modules

if vim.fn.executable("gtags") and vim.fn.executable("gtags-cscope") then
	vim.env.GTAGSLABEL = 'native'
	if vim.fn.has("unix") then
		vim.env.GTAGSCONF='/usr/share/gtags/gtags.conf'
	elseif vim.fn.has("macunix") then
		vim.env.GTAGSCONF = '/usr/local/share/gtags/gtags.conf'
	end
end
