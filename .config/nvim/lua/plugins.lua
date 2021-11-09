local execute = vim.api.nvim_command
local fn = vim.fn
-- /Users/username/.local/share/nvim/site/pack/packer/start/packer.nvim
local packer_install_dir = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
local is_linux = true

if is_linux then
	plug_url_format = 'https://hub.fastgit.org/%s'
else
	plug_url_format = 'https://github.com/%s'
end

local packer_repo = string.format(plug_url_format, 'wbthomason/packer.nvim')
local install_cmd = string.format('10split |term git clone --depth=1 %s %s', packer_repo, packer_install_dir)

if fn.empty(fn.glob(packer_install_dir)) > 0 then
	vim.api.nvim_echo({{'Installing packer.nvim', 'Type'}}, true, {})
	-- execute 'packadd packer.nvim'
end

vim.cmd [[packadd packer.nvim]]

-- https://github.com/wbthomason/packer.nvim#requirements
return require('packer').startup(function()
	-- Packer can manage itself
	use 'wbthomason/packer.nvim'
	use 'bronson/vim-trailing-whitespace'
	--使用 ALT+e 会在不同窗口/标签上显示 A/B/C 等编号，然后字母直接跳转
	use 't9md/vim-choosewin'
	use 'tpope/vim-fugitive'
	use 'lambdalisue/fern.vim'
	use 'skywind3000/vim-preview'
	use 'skywind3000/vim-quickui'
	use 'skywind3000/asynctasks.vim'
	use 'skywind3000/asyncrun.vim'
	use 'skywind3000/gutentags_plus'
	use 'Yggdroot/LeaderF'
	use 'neovim/nvim-lspconfig'
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
	use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
	use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
	use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use 'antoinemadec/FixCursorHold.nvim'
	use 'ludovicchabant/vim-gutentags'
	use 'mhinz/vim-signify'
	-- 基础插件：提供让用户方便的自定义文本对象的接口
	use 'kana/vim-textobj-user'

	-- indent 文本对象：ii/ai 表示当前缩进，vii 选中当缩进，cii 改写缩进
	use 'kana/vim-textobj-indent'

	-- 语法文本对象：iy/ay 基于语法的文本对象
	use 'kana/vim-textobj-syntax'

	-- 函数文本对象：if/af 支持 c/c++/vim/java
	use 'kana/vim-textobj-function'

	-- 参数文本对象：i,/a, 包括参数或者列表元素
	use  'sgur/vim-textobj-parameter'

	-- 提供 python 相关文本对象，if/af 表示函数，ic/ac 表示类
	use 'bps/vim-textobj-python'

	-- 提供 uri/url 的文本对象，iu/au 表示
	use 'jceb/vim-textobj-uri'

	use 'Chiel92/vim-autoformat'
	-- 自动调整窗口
	use 'camspiers/lens.vim'
	use 'ojroques/vim-oscyank'
	use 'mg979/vim-visual-multi'
	use "lukas-reineke/indent-blankline.nvim"
end)
