local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "--single-branch",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  }
end
vim.opt.runtimepath:prepend(lazypath)

require("lazy").setup {
  -- {
  --   "lewis6991/impatient.nvim",
  --   config = function()
  --     require "impatient"
  --   end,
  -- },

  { "ludovicchabant/vim-gutentags" },

  {
    "skywind3000/gutentags_plus",
    config = function()
      require "config/gtags"
    end,
  },

  --
  { "skywind3000/vim-preview" },
  { "skywind3000/vim-quickui" },
  { "skywind3000/asynctasks.vim" },
  { "skywind3000/asyncrun.vim" },

  {
    "Yggdroot/LeaderF",
    -- keys = {"<m-n>", "<m-p>", "<m-m>", "<c-p>"},
    config = function()
      require "config/leaderf"
    end,
  },

  {
    "neovim/nvim-lspconfig",
    tag = "v0.1.3",
  },

  -- -- adds vscode-like pictograms to neovim built-in lsp
  { "onsails/lspkind-nvim" },

  -- LSP source for nvim-cmp
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-cmdline" },

  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-nvim-lsp-document-symbol" },
  { "tamago324/cmp-zsh" },
  { "lukas-reineke/cmp-rg" },

  --
  {
    "L3MON4D3/LuaSnip",
    config = function()
      require "config/lua_snip"
    end,
  },

  {
    "rafamadriz/friendly-snippets",
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
  { "saadparwaiz1/cmp_luasnip" },

  {
    "hrsh7th/nvim-cmp", -- Autocompletion plugin
    dependencies = {
      {
        "quangnguyen30192/cmp-nvim-tags",
        -- if you want the sources is available for some file types
        ft = {
          "go",
          "rust",
        },
      },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "config/gitsigns"
    end,
    event = { "BufRead", "BufNewFile" },
  },

  -- 参数文本对象：i,/a, 包括参数或者列表元素
  { "sgur/vim-textobj-parameter", dependencies = { "kana/vim-textobj-user" } },

  -- 提供cs'"这种快捷键
  -- use "tpope/vim-surround"
  --
  -- use "tpope/vim-repeat"
  --
  {
    "kylechui/nvim-surround",
    config = function()
      require("nvim-surround").setup {
        -- Configuration here, or leave empty to use defaults
      }
    end,
  },

  -- -- 自动调整窗口
  -- replaced with window.nvim
  { "camspiers/lens.vim" },

  {
    "glepnir/galaxyline.nvim",
    branch = "main",
    -- your statusline
    config = function()
      require "config/galaxy"
    end,
    -- some optional icons
    dependencies = { "kyazdani42/nvim-web-devicons", opt = true },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      -- vim.opt.list = true
      -- vim.opt.listchars:append "space:⋅"
      -- vim.opt.listchars:append "eol:↴"
      require("indent_blankline").setup {
        space_char_blankline = " ",
        show_current_context = true,
        show_end_of_line = true,
      }
    end,
  },

  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  -- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    config = function()
      require "config/text_obj"
    end,
  },

  { "nvim-treesitter/nvim-treesitter-context" },

  { "dstein64/vim-startuptime", cmd = "StartupTime" },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  -- terminal
  {
    "akinsho/toggleterm.nvim",
    config = function()
      require "config/terminal"
    end,
    branch = "main",
  },

  -- colorscheme
  { "EdenEast/nightfox.nvim" },
  {
    "daschw/leaf.nvim",
    config = function()
      require("leaf").setup { theme = "dark" }
    end,
  },

  -- bracket, brace auto complete
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup {}
    end,
  },

  {
    "jose-elias-alvarez/null-ls.nvim",
    config = function()
      require "config/null_ls"
    end,
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- show signature
  {
    "ray-x/lsp_signature.nvim",
  },

  {
    "TimUntersberger/neogit",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require "config/neogit"
    end,
  },

  {
    "rlane/pounce.nvim",
  },

  {
    "nvim-lua/lsp_extensions.nvim",
  },

  {
    "saecki/crates.nvim",
    tag = "v0.1.0",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup()
    end,
  },

  -- used to show lsp init progress
  -- use {
  --   "j-hui/fidget.nvim",
  --   config = function()
  --     require("fidget").setup {}
  --   end,
  -- }

  --使用 ALT+e 会在不同窗口/标签上显示 A/B/C 等编号，然后字母直接跳转
  -- use "t9md/vim-choosewin"

  {
    "simrat39/rust-tools.nvim",
  },

  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "kyazdani42/nvim-web-devicons", opt = true },
    config = function()
      require "config/diff"
    end,
  },

  --
  {
    "RRethy/vim-illuminate",
    config = function()
      require "config/illuminate"
    end,
  },

  {
    "karb94/neoscroll.nvim",
    config = function()
      require "config/neoscroll"
    end,
  },

  {
    "kevinhwang91/nvim-hlslens",
    config = function()
      require "config/hlslen"
    end,
  },

  {
    "abecodes/tabout.nvim",
    config = function()
      require "config/tabout"
    end,
    dependencies = {
      "hrsh7th/nvim-cmp", -- Autocompletion plugin
      "nvim-treesitter/nvim-treesitter",
    },
  },

  --
  {
    "p00f/nvim-ts-rainbow",
  },
  --
  {
    "nacro90/numb.nvim",
    config = function()
      require("numb").setup()
    end,
  },

  {
    "ziontee113/syntax-tree-surfer",
    config = function()
      require "config/surfer"
    end,
  },
  {
    "nmac427/guess-indent.nvim",
    config = function()
      require("guess-indent").setup {}
    end,
  },

  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    config = function()
      require "config/ufo"
    end,
  },

  --
  {
    "akinsho/bufferline.nvim",
    -- tag = "v2.*",
    dependencies = { "kyazdani42/nvim-web-devicons" },
    config = function()
      require "config/bufferline"
    end,
  },

  -- {
  --   "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
  --   config = function()
  --     require("lsp_lines").setup {}
  --     vim.diagnostic.config {
  --       virtual_text = false,
  --     }
  --   end,
  -- },

  { "folke/tokyonight.nvim" },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v2.x",
    keys = { { "nc", "nC", "ne", "nb" } },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "kyazdani42/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require "config/neotree"
    end,
  },

  {
    "mfussenegger/nvim-dap",
    config = function()
      require "config/dap"
    end,
  },

  { "rcarriga/nvim-dap-ui", dependencies = { "mfussenegger/nvim-dap" } },

  {
    "gennaro-tedesco/nvim-peekup",
  },
}
