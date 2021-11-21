local u = require("util")
local present, util_packer = pcall(require, 'util.packer')

if not present then
	return false
end

local packer = util_packer.packer
local use = packer.use


local ok, err = pcall(require, "compiled")
if not ok then
	error('Run :PackerCompile!')
end


vim.cmd([[
	augroup packer_user_config
		autocmd!
		autocmd BufWritePost init.lua source <afile> | PackerCompile
	augroup end
]])


local function getCodeLang()
	return {"go", "rust", "zig", "c", "cpp", "lua"}
end

--
return packer.startup(function()
	-- Packer can manage itself
	use 'wbthomason/packer.nvim'
	use {
		'lewis6991/impatient.nvim',
	    config = function()
			require("impatient")
		end,
	}

	use("nathom/filetype.nvim")

	use 'bronson/vim-trailing-whitespace'
	--使用 ALT+e 会在不同窗口/标签上显示 A/B/C 等编号，然后字母直接跳转
	use 't9md/vim-choosewin'
	use 'tpope/vim-fugitive'
	use {
		'lambdalisue/fern.vim',
		keys = {"nc", "nC", "ne", "nE"},
		config = function()
			require("config/fern")
		end,
	}

	use {
		'ludovicchabant/vim-gutentags'
	}

	use {
		'skywind3000/gutentags_plus',
		config = function()
			require("config/gtags")
		end,
	}


	use 'skywind3000/vim-preview'
	use 'skywind3000/vim-quickui'
	use 'skywind3000/asynctasks.vim'
	use 'skywind3000/asyncrun.vim'

	use {
		'Yggdroot/LeaderF',
		keys = {"<m-n>", "<m-p>", "<m-m>"},
		config = function()
			require("config/leaderf")
		end,
	}

	use {
		'neovim/nvim-lspconfig'
	}
	use {
		'hrsh7th/nvim-cmp' -- Autocompletion plugin
	}
	use {
		'hrsh7th/cmp-nvim-lsp'  -- LSP source for nvim-cm
	}
	use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
	use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use 'antoinemadec/FixCursorHold.nvim'

	use {
		'mhinz/vim-signify',
		config = function()
			require 'config/signify'
		end
	}

	-- 基础插件：提供让用户方便的自定义文本对象的接口
	use 'kana/vim-textobj-user'

	local fullBuffPath = u.getFileFullPath

	-- statusline
	--	use {
	--		'nvim-lualine/lualine.nvim',
	--		requires = {'kyazdani42/nvim-web-devicons', opt = true},
	--		config = require("lualine").setup({
	--		sections = {
	--			lualine_c = {fullBuffPath}
	--		}})
	--	}
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

	-- 复制剪切板
	use 'ojroques/vim-oscyank'

	use 'mg979/vim-visual-multi'

	-- indent-line
	use "lukas-reineke/indent-blankline.nvim"

	-- treesitter
	use {
		'nvim-treesitter/nvim-treesitter',
		run = ':TSUpdate'
	}

	use 'nvim-treesitter/nvim-treesitter-textobjects'

	use 'dstein64/vim-startuptime'

	use {
		'numToStr/Comment.nvim',
		config = function()
			require('Comment').setup()
		end
	}

	-- terminal
	use ({
		"akinsho/toggleterm.nvim",
		config = function()
			require("config/terminal")
		end
	})

	-- colorscheme
	use {'Mofiqul/vscode.nvim'}
	use {'christianchiarulli/nvcode-color-schemes.vim'}
	use {"bluz71/vim-moonfly-colors"}

	-- bracket, brace auto complete
	use ({
		"windwp/nvim-autopairs",
		config = function()
			require('nvim-autopairs').setup{}
		end,
	})

	-- show signature
	use {
	  "ray-x/lsp_signature.nvim",
	}

	use 'ggandor/lightspeed.nvim'

	if util_packer.first_install then
		packer.sync()
	end
end)

