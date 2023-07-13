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

-- make sure to set `mapleader` before lazy so your mappings are correct
-- u.map("n", "<space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocalleader = " "

if os.getenv "NVIM" ~= nil then
  require("lazy").setup {
    { "willothy/flatten.nvim", config = true },
  }
  return
end

require("lazy").setup {

  {
    "ludovicchabant/vim-gutentags",
    config = function()
      require "config/gtags"
    end,
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "python" },
  },

  { "skywind3000/vim-preview" },
  { "skywind3000/vim-quickui" },
  { "skywind3000/asynctasks.vim" },
  { "skywind3000/asyncrun.vim" },

  {
    "Yggdroot/LeaderF",
    keys = { { "<m-n>" }, { "<m-p>" }, { "<m-m>" }, { "<c-p>" }, { "<m-l>" } },
    config = function()
      require "config/leaderf"
    end,
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

  {
    "hrsh7th/nvim-cmp", -- Autocompletion plugin
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-nvim-lsp-document-symbol",
      "tamago324/cmp-zsh",
    },
    event = "InsertEnter",
    config = function()
      require "config/cmp"
    end,
  },

  --
  {
    "L3MON4D3/LuaSnip",
    config = function()
      require "config/lua_snip"
    end,
    build = "make install_jsregexp",
    ft = { "go", "lua", "c", "rust", "cpp", "yaml", "json", "python" },
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
    ft = { "go", "lua", "c", "rust", "cpp", "yaml", "json", "python" },
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

  { "tpope/vim-repeat", ft = { "go", "zig", "rust", "lua", "c", "cpp", "python" } },

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

  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "yaml", "json", "proto", "markdown" },
  },

  -- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  -- {
  --   "nvim-treesitter/nvim-treesitter-textobjects",
  --   config = function()
  --     require "config/text_obj"
  --   end,
  --   ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  -- },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "python" },
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

  { "rebelot/kanagawa.nvim" },

  {
    "daschw/leaf.nvim",
    config = function()
      require("leaf").setup { theme = "dark" }
    end,
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    build = ":CatppuccinCompile",
    enabled = true,
    opts = {
      transparent = true,
      term_clors = true,
    },
  },
  -- bracket, brace auto complete
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup {}
    end,
    event = "InsertEnter",
  },

  -- {
  --   "jose-elias-alvarez/null-ls.nvim",
  --   config = function()
  --     require "config/null_ls"
  --   end,
  --   dependencies = { "nvim-lua/plenary.nvim" },
  --   ft = { "go", "c", "cpp", "rust", "zig", "lua", "python" },
  -- },

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
    "nvim-lua/lsp_extensions.nvim",
    ft = { "go", "c", "cpp", "rust", "zig", "lua" },
  },

  {
    "saecki/crates.nvim",
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
    tag = "legacy",
    event = "LspAttach",
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
    event = "InsertEnter",
  },

  {
    "kevinhwang91/nvim-hlslens",
    config = function()
      require "config/hlslen"
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

  {
    "ThePrimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      mark = require "harpoon.mark"
      vim.keymap.set("n", "<space>1", function()
        mark.add_file()
      end)
    end,
  },

  {
    "akinsho/bufferline.nvim",
    -- tag = "v2.*",
    dependencies = { "kyazdani42/nvim-web-devicons" },
    config = function()
      require "config/bufferline"
    end,
  },

  -- colorscheme
  { "folke/tokyonight.nvim" },

  {
    "gennaro-tedesco/nvim-peekup",
  },

  {
    "AckslD/nvim-neoclip.lua",
    dependencies = {
      { "nvim-telescope/telescope.nvim" },
    },
    config = function()
      require("neoclip").setup {
        default_register = { '"', "+", "*" },
        keys = {
          telescope = {
            i = {
              -- default key is <c-k> whici is conflict with telescope.nvim
              -- https://github.com/AckslD/nvim-neoclip.lua
              paste_behind = "<Nop>",
            },
          },
        },
      }
    end,
    event = "InsertEnter",
  },

  {
    "akinsho/git-conflict.nvim",
    version = "*",
    config = function()
      require("git-conflict").setup {}
    end,
  },

  {
    "VidocqH/lsp-lens.nvim",
    config = function()
      require("lsp-lens").setup {
        enable = true,
        sections = { -- Enable / Disable specific request
          definition = true,
          references = true,
          implementation = true,
        },
      }
    end,
    event = "LspAttach",
  },

  {
    "Exafunction/codeium.vim",
    config = function()
      require "config/codeium"
    end,
    event = "InsertEnter",
  },

  {
    "jcdickinson/codeium.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      require("codeium").setup {}
    end,
    event = "InsertEnter",
  },

  {
    "dpayne/CodeGPT.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
    ft = { "go", "c", "cpp", "rust", "zig", "lua", "python", "markdown" },
  },

  {
    "ojroques/nvim-osc52",
    config = function()
      vim.keymap.set("n", ",c", require("osc52").copy_operator, { expr = true })
      vim.keymap.set("x", ",c", require("osc52").copy_visual)
    end,
    event = "InsertEnter",
  },

  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.1",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require "config/telescope"
    end,
    keys = { { ",tg", mode = "n" }, { ",ts", mode = "n" } },
  },

  {
    "lvimuser/lsp-inlayhints.nvim",
    config = function()
      require("lsp-inlayhints").setup {
        debug_mode = false,
      }
    end,
    branch = "anticonceal",
    event = "LspAttach",
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
    },
  },

  -- skip to inner bracket
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
  },

  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup {
        log_level = "error",
        auto_session_supress_dir = { "~/" },
      }
    end,
  },

  {
    "rmagatti/session-lens",
    dependencies = { "nvim-telescope/telescope.nvim", "rmagatti/auto-session" },
    config = function()
      require("session-lens").setup()
    end,
  },

  {
    "willothy/flatten.nvim",
    config = true,
    -- or pass configuration with
    -- opts = {  }
    -- Ensure that it runs first to minimize delay when opening file from terminal
    lazy = false,
    priority = 1001,
  },

  {
    "jvgrootveld/telescope-zoxide",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    event = { "VeryLazy" },
  },

  {
    "tzachar/cmp-tabnine",
    build = "./install.sh",
    dependencies = "hrsh7th/nvim-cmp",
    event = "InsertEnter",
  },

  -- {
  --   "mhartington/formatter.nvim",
  --   config = function()
  --     require "config/format"
  --   end,
  --   event = "InsertEnter",
  -- },

  -- protject notes
  { "JellyApple102/flote.nvim" },

  {
    "mrjones2014/smart-splits.nvim",
    build = "./kitty/install-kittens.bash",
    config = function()
      require("smart-splits").setup {
        multiplexer = "tmux",
        -- use less ctrl + h/j/k/l for terminal key which has specific behavior
        vim.keymap.set("n", "<C-h>", require("smart-splits").move_cursor_left),

        -- vim.keymap.set("n", "<C-j>", require("smart-splits").move_cursor_down),
        -- vim.keymap.set("n", "<C-k>", require("smart-splits").move_cursor_up),
        -- vim.keymap.set("n", "<C-l>", require("smart-splits").move_cursor_right),
      }
    end,
    event = "VeryLazy",
  },
  -- color scheme
  {
    "hardhackerlabs/theme-vim",
    config = function()
      vim.cmd.colorscheme "hardhacker"
    end,
  },

  {
    "junnplus/lsp-setup.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim", -- optional
      "williamboman/mason-lspconfig.nvim", -- optional
    },
    branch = "inlay-hints",
    config = function()
      require "config/lsp"
    end,
  },
}
