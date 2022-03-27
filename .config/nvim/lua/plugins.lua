local u = require "util"
local present, util_packer = pcall(require, "util.packer")

if not present then
  return false
end

local packer = util_packer.packer
local use = packer.use

local ok, err = pcall(require, "compiled")
if not ok then
  error "Run :PackerCompile!"
end

vim.cmd [[
augroup packer_user_config
    autocmd!
    autocmd BufWritePost init.lua source <afile> | PackerCompile
augroup end
]]

--
return packer.startup(function()
  -- Packer can manage itself
  use "wbthomason/packer.nvim"
  use {
    "lewis6991/impatient.nvim",
    config = function()
      require "impatient"
    end,
  }

  use "nathom/filetype.nvim"

  use "bronson/vim-trailing-whitespace"

  use {
    "tpope/vim-fugitive",
    config = function()
      require "config/fugtive"
    end,
  }

  use {
    "lambdalisue/fern.vim",
    keys = { "nc", "nC", "ne", "nE" },
    config = function()
      require "config/fern"
    end,
  }

  use "ludovicchabant/vim-gutentags"

  use {
    "skywind3000/gutentags_plus",
    config = function()
      require "config/gtags"
    end,
  }

  use "skywind3000/vim-preview"
  use "skywind3000/vim-quickui"
  use "skywind3000/asynctasks.vim"
  use "skywind3000/asyncrun.vim"

  use {
    "Yggdroot/LeaderF",
    -- keys = {"<m-n>", "<m-p>", "<m-m>", "<c-p>"},
    config = function()
      require "config/leaderf"
    end,
  }

  use "neovim/nvim-lspconfig"
  -- adds vscode-like pictograms to neovim built-in lsp
  use "onsails/lspkind-nvim"
  use "hrsh7th/nvim-cmp" -- Autocompletion plugin

  use "hrsh7th/cmp-nvim-lsp" -- LSP source for nvim-cmp
  use "hrsh7th/cmp-cmdline"
  use "hrsh7th/cmp-buffer"
  use "hrsh7th/cmp-path"
  use "hrsh7th/cmp-nvim-lua"
  use "hrsh7th/cmp-nvim-lsp-document-symbol"
  use "tamago324/cmp-zsh"

  use "saadparwaiz1/cmp_luasnip" -- Snippets source for nvim-cmp
  use {
    "L3MON4D3/LuaSnip",
    config = function()
      require "config/lua_snip"
    end,
  }
  use "antoinemadec/FixCursorHold.nvim"

  -- use {
  --     'mhinz/vim-signify',
  --     config = function()
  --         require 'config/signify'
  --     end
  -- }

  use {
    "lewis6991/gitsigns.nvim",
    requires = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "config/gitsigns"
    end,
  }

  -- 基础插件：提供让用户方便的自定义文本对象的接口
  use "kana/vim-textobj-user"

  -- indent 文本对象：ii/ai 表示当前缩进，vii 选中当缩进，cii 改写缩进
  use "kana/vim-textobj-indent"

  -- 参数文本对象：i,/a, 包括参数或者列表元素
  use "sgur/vim-textobj-parameter"

  use "tpope/vim-surround"

  use "tpope/vim-repeat"

  -- use 'Chiel92/vim-autoformat'

  -- 自动调整窗口
  use "camspiers/lens.vim"

  -- 复制剪切板
  use "ojroques/vim-oscyank"

  use "mg979/vim-visual-multi"

  -- indent-line
  use {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      require("indent_blankline").setup {
        space_char_blankline = " ",
        show_current_context = true,
        show_end_of_line = true,
      }
    end,
  }

  -- treesitter
  use {
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
  }

  -- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  use {
    "nvim-treesitter/nvim-treesitter-textobjects",
    config = function()
      require "config/text_obj"
    end,
  }

  use "dstein64/vim-startuptime"

  use {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  }

  -- terminal
  use {
    "akinsho/toggleterm.nvim",
    config = function()
      require "config/terminal"
    end,
  }

  -- colorscheme
  use { "Mofiqul/vscode.nvim" }
  -- use {'christianchiarulli/nvcode-color-schemes.vim'}
  -- use {"bluz71/vim-moonfly-colors"}
  -- use {"lukas-reineke/onedark.nvim" }
  use { "EdenEast/nightfox.nvim" }

  -- bracket, brace auto complete
  use {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup {}
    end,
  }

  use {
    "jose-elias-alvarez/null-ls.nvim",
    config = function()
      require "config/null_ls"
    end,
    requires = { "nvim-lua/plenary.nvim" },
  }
  -- show signature
  use {
    "ray-x/lsp_signature.nvim",
  }

  use {
    "pacha/vem-tabline",
  }
  use {
    "ryanoasis/vim-devicons",
  }

  use {
    "TimUntersberger/neogit",
    requires = "nvim-lua/plenary.nvim",
    config = function()
      require "config/neogit"
    end,
  }

  use {
    "rlane/pounce.nvim",
  }

  -- Lua
  -- use {
  --   "folke/todo-comments.nvim",
  --   requires = "nvim-lua/plenary.nvim",
  --   config = function()
  --     require("todo-comments").setup {}
  --   end,
  -- }
  use {
    "karb94/neoscroll.nvim",
    config = function()
      require "config/neoscroll"
    end,
  }

  use {
    "saecki/crates.nvim",
    tag = "v0.1.0",
    requires = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup()
    end,
  }

  --使用 ALT+e 会在不同窗口/标签上显示 A/B/C 等编号，然后字母直接跳转
  -- use 't9md/vim-choosewin'

  -- use {
  --     'nvim-telescope/telescope.nvim',
  --     requires = { {'nvim-lua/plenary.nvim'} }
  -- }
  if util_packer.first_install then
    packer.sync()
  end
end)
