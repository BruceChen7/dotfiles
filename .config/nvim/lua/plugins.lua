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

  {
    "ludovicchabant/vim-gutentags",
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
    keys = { "<m-n>", "<m-p>", "<m-m>", "<c-p>" },
    config = function()
      require "config/leaderf"
    end,
  },

  {
    "neovim/nvim-lspconfig",
    tag = "v0.1.6",
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "python" },
  },

  -- -- adds vscode-like pictograms to neovim built-in lsp
  { "onsails/lspkind-nvim" },

  {
    "rmagatti/goto-preview",
    config = function()
      require("goto-preview").setup {
        default_mappings = true,
      }
    end,
  },

  {
    "lambdalisue/fern.vim",
    config = function()
      require "config/fern"
    end,
    keys = { { "nc" }, { "ne" }, { "nC" }, { "nE" } },
  },
  --
  -- LSP source for nvim-cmp
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-cmdline" },

  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-nvim-lsp-document-symbol" },
  { "tamago324/cmp-zsh" },
  -- { "lukas-reineke/cmp-rg" },

  --
  {
    "L3MON4D3/LuaSnip",
    config = function()
      require "config/lua_snip"
    end,
    ft = { "go", "lua", "c", "rust", "cpp", "yaml", "json" },
  },

  {
    "rafamadriz/friendly-snippets",
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
    ft = { "go", "lua", "c", "rust", "cpp" },
  },
  {
    "saadparwaiz1/cmp_luasnip",
    ft = { "go", "lua", "c", "rust", "cpp", "yaml", "json" },
  },

  {
    "hrsh7th/nvim-cmp", -- Autocompletion plugin
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
  {
    "sgur/vim-textobj-parameter",
    dependencies = { "kana/vim-textobj-user" },
    ft = { "go", "zig", "rust", "lua", "c", "cpp", "python" },
  },

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
    -- event = { "BufRead", "BufNewFile" },
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  -- -- 自动调整窗口
  -- replaced with window.nvim
  { "camspiers/lens.vim" },

  -- {
  --   "glepnir/galaxyline.nvim",
  --   branch = "main",
  --   -- your statusline
  --   config = function()
  --     require "config/galaxy"
  --   end,
  --   -- some optional icons
  --   dependencies = { "kyazdani42/nvim-web-devicons", opt = true },
  -- },

  {
    "ojroques/nvim-hardline",
    config = function()
      require("hardline").setup {
        bufferline = false, -- disable bufferline
        bufferline_settings = {
          exclude_terminal = false, -- don't show terminal buffers in bufferline
          show_index = false, -- show buffer indexes (not the actual buffer numbers) in bufferline
        },
        theme = "default", -- change theme
        sections = { -- define sections
          { class = "mode", item = require("hardline.parts.mode").get_item },
          { class = "med", item = require("hardline.parts.filename").get_item },
          { class = "high", item = require("hardline.parts.filetype").get_item },
          "%<",
          { class = "med", item = "%=" },
          { class = "error", item = require("hardline.parts.lsp").get_error },
          { class = "warning", item = require("hardline.parts.lsp").get_warning },
          { class = "high", item = require("hardline.parts.git").get_item, hide = 100 },
        },
      }
    end,
  },

  -- {
  --   "lukas-reineke/indent-blankline.nvim",
  --   config = function()
  --     -- vim.opt.list = true
  --     -- vim.opt.listchars:append "space:⋅"
  --     -- vim.opt.listchars:append "eol:↴"
  --     require("indent_blankline").setup {
  --       space_char_blankline = " ",
  --       show_current_context = true,
  --       show_end_of_line = true,
  --     }
  --   end,
  --   ft = { "go", "zig", "rust", "lua", "c", "cpp", "python" },
  -- },

  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "yaml", "json", "proto", "markdown" },
  },

  -- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    config = function()
      require "config/text_obj"
    end,
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  -- terminal
  {
    "akinsho/toggleterm.nvim",
    config = function()
      require "config/terminal"
    end,
    branch = "main",
    keys = { { "<m-=>", mode = "n" }, { "<space>tb", mode = "n" } },
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
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "python" },
  },

  -- show signature
  {
    "ray-x/lsp_signature.nvim",
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  {
    "TimUntersberger/neogit",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require "config/neogit"
    end,
    keys = { { "<space>gg", mode = "n" } },
  },

  {
    "rlane/pounce.nvim",
  },

  {
    "nvim-lua/lsp_extensions.nvim",
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  {
    "saecki/crates.nvim",
    tag = "v0.1.0",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup()
    end,
    ft = { "rust" },
  },

  -- used to show lsp init progress
  {
    "j-hui/fidget.nvim",
    config = function()
      require("fidget").setup {}
    end,
  },
  --使用 ALT+e 会在不同窗口/标签上显示 A/B/C 等编号，然后字母直接跳转
  -- use "t9md/vim-choosewin"
  {
    "simrat39/rust-tools.nvim",
    ft = { "rust" },
  },

  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "kyazdani42/nvim-web-devicons", opt = true },
    config = function()
      require "config/diff"
    end,
    keys = { { "<space>gg", mode = "n" } },
  },

  --
  {
    "RRethy/vim-illuminate",
    config = function()
      require "config/illuminate"
    end,
    event = "InsertEnter",
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
    event = "InsertEnter",
  },

  --
  -- {
  --   "p00f/nvim-ts-rainbow",
  -- },
  --
  {
    "nacro90/numb.nvim",
    config = function()
      require("numb").setup()
    end,
  },

  -- {
  --   "ziontee113/syntax-tree-surfer",
  --   config = function()
  --     require "config/surfer"
  --   end,
  --   ft = { "go", "c", "cpp", "zig" },
  -- },
  {
    "nmac427/guess-indent.nvim",
    config = function()
      require("guess-indent").setup {}
    end,
    event = "InsertEnter",
  },

  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    ft = { "go", "lua", "c", "rust", "cpp" },
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

  -- {
  --   "LunarVim/bigfile.nvim",
  --   ft = { "go", "lua", "c", "rust", "cpp", "proto" },
  -- },

  -- {
  --
  --   "nvim-neo-tree/neo-tree.nvim",
  --   branch = "v2.x",
  --   keys = { { "nc", "nC", "ne", "nb" } },
  --   dependencies = {
  --     "nvim-lua/plenary.nvim",
  --     "kyazdani42/nvim-web-devicons", -- not strictly required, but recommended
  --     "MunifTanjim/nui.nvim",
  --   },
  --   config = function()
  --     require "config/neotree"
  --   end,
  -- },

  -- {
  --   "m4xshen/smartcolumn.nvim",
  --   opts = {
  --     scope = "line",
  --   },
  -- },

  -- {
  --   "mfussenegger/nvim-dap",
  --   config = function()
  --     require "config/dap"
  --   end,
  --   ft = { "go", "lua", "c", "rust", "cpp" },
  -- },

  {
    "gennaro-tedesco/nvim-peekup",
  },

  {
    "Exafunction/codeium.vim",
    config = function()
      require "config/codeium"
    end,
    ft = { "go", "lua", "c", "rust", "cpp", "zig", "cpp", "python" },
  },

  { "dpayne/CodeGPT.nvim", dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" } },

  {
    "ojroques/nvim-osc52",
    config = function()
      vim.keymap.set("n", ",c", require("osc52").copy_operator, { expr = true })
      -- vim.keymap.set("n", "<leader>cc", "<leader>c_", { remap = true })
      vim.keymap.set("x", ",c", require("osc52").copy_visual)
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
    event = "InsertEnter",
    ft = { "go", "lua", "c", "rust", "cpp", "zig", "cpp", "python", "markdown" },
  },
}
