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

require("lazy").setup {

  {
    "ludovicchabant/vim-gutentags",
    config = function()
      require "config/gtags"
    end,
    event = "VeryLazy",
  },

  { "skywind3000/vim-preview" },
  { "skywind3000/vim-quickui" },
  { "skywind3000/asynctasks.vim" },
  { "skywind3000/asyncrun.vim" },

  {
    "Yggdroot/LeaderF",
    config = function()
      require "config/leaderf"
    end,
    event = "VeryLazy",
  },

  -- -- adds vscode-like pictograms to neovim built-in lsp
  { "onsails/lspkind-nvim" },

  {
    "lambdalisue/fern.vim",
    config = function()
      require "config/fern"
    end,
    event = "VeryLazy",
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
    branch = "main",
    -- https://www.reddit.com/r/neovim/comments/162q5ca/whats_your_favorite_unknown_nvimvim_plugin/
    commit = "6c84bc75c64f778e9f1dcb798ed41c7fcb93b639",
  },

  --
  {
    "L3MON4D3/LuaSnip",
    config = function()
      require "config/lua_snip"
    end,
    build = "make install_jsregexp",
    event = "InsertEnter",
  },

  {
    "rafamadriz/friendly-snippets",
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
    event = "InsertEnter",
  },
  {
    "saadparwaiz1/cmp_luasnip",
    event = "InsertEnter",
  },

  {
    "anuvyklack/hydra.nvim",
    event = "VeryLazy",
    config = function()
      require "config/hydra"
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "config/gitsigns"
    end,
    event = "VeryLazy",
  },

  -- -- 自动调整窗口
  -- replaced with window.nvim
  { "camspiers/lens.vim" },

  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = "VeryLazy",
    config = function()
      require "config/text_obj"
    end,
  },

  {
    "sustech-data/wildfire.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("wildfire").setup()
    end,
  },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
    event = "VeryLazy",
  },

  -- terminal
  {
    "akinsho/toggleterm.nvim",
    config = function()
      require "config/terminal"
    end,
    branch = "main",
    event = "VeryLazy",
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
  -- show signature
  {
    "ray-x/lsp_signature.nvim",
    event = "LspAttach",
    opts = {},
    config = function(_, opts)
      require("lsp_signature").setup(opts)
    end,
  },

  {
    "TimUntersberger/neogit",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require "config/neogit"
    end,
    event = "VeryLazy",
  },

  {
    "nvim-lua/lsp_extensions.nvim",
    event = "VeryLazy",
  },

  {
    "dhananjaylatkar/cscope_maps.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim", -- optional [for picker="telescope"]
      "nvim-tree/nvim-web-devicons", -- optional [for devicons in telescope or fzf]
    },
    opts = {
      skip_input_prompt = true,
      cscope = {
        exec = "gtags-cscope",
        picker = "telescope",
        skip_picker_for_single_result = true,
        db_build_cmd_args = { "-bqkv" },
      },
    },
  },

  {
    "saecki/crates.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup()
    end,
    ft = { "rust" },
  },

  {
    "linrongbin16/lsp-progress.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lsp-progress").setup()
    end,
  },

  {
    "simrat39/rust-tools.nvim",
    ft = { "rust" },
  },

  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", opt = true },
    config = function()
      require "config/diff"
    end,
    event = "VeryLazy",
  },

  {
    "karb94/neoscroll.nvim",
    config = function()
      require "config/neoscroll"
    end,
    event = "VeryLazy",
  },

  {
    "kevinhwang91/nvim-hlslens",
    config = function()
      require "config/hlslen"
    end,
    event = "VeryLazy",
  },

  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "VeryLazy",
    config = function()
      require "config/ufo"
    end,
  },

  {
    "ThePrimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local mark = require "harpoon.mark"
      local ui = require "harpoon.ui"
      local term = require "harpoon.term"
      vim.keymap.set("n", "m1", function()
        mark.add_file()
      end)
      -- next marks
      vim.keymap.set("n", ",hn", function()
        ui.nav_next()
      end)
      --prev marks
      vim.keymap.set("n", ",hp", function()
        ui.nav_prev()
      end)

      vim.keymap.set("n", ",hf", function()
        ui.toggle_quick_menu()
      end)

      vim.keymap.set("n", "m2", function()
        term.gotoTerminal(1)
      end)
    end,
  },

  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
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
    event = "VeryLazy",
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
        ignore_filetype = {
          "fern",
          "NeogitStatus",
          "DiffviewFiles",
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
    "ojroques/nvim-osc52",
    config = function()
      vim.keymap.set("n", ",c", require("osc52").copy_operator, { expr = true })
      vim.keymap.set("x", ",c", require("osc52").copy_visual)
    end,
    event = "VeryLazy",
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require "config/telescope"
    end,
    event = "VeryLazy",
  },

  -- https://github.com/Innei/nvim-config-lua/blob/2b311daa7841af52226fc9b75add357c03eac078/lua/plugins/motion.lua#L10
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        search = {
          enabled = false,
        },
        char = {
          keys = {
            "f",
            "F",
            "t",
            "T",
          },
        },
      },
    },
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
    event = "VeryLazy",
  },

  {
    "rmagatti/auto-session",
    config = function()
      local close_not_in_working_dir = function()
        local close_window_by_bufname = function(buffer_name)
          local buf = vim.fn.bufnr(buffer_name)
          if buf ~= -1 then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end

        local function isPartOfPath(path, potentialSubpath)
          local normalizedPath = path:gsub("[/\\]$", "")
          local normalizedSubpath = potentialSubpath:gsub("[/\\]$", "")

          -- Check if the normalized subpath is contained within the normalized path
          if string.find(normalizedSubpath, normalizedPath, 1, true) then
            return true
          end

          return false
        end
        for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
          local buf_name = vim.api.nvim_buf_get_name(buffer)
          local buf_nr = vim.fn.bufnr(buf_name)
          local filetype = vim.api.nvim_buf_get_option(buf_nr, "filetype")

          if buf_name ~= "" then
            local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
            if string.find(buf_name, "fern:") then
              close_window_by_bufname(buf_name)
            end
            if string.find(buf_name, "gitcommit") then
              -- print("fern buffer", buf_name)
              close_window_by_bufname(buf_name)
            end
            local cur_dir = vim.fn.getcwd()
            if isPartOfPath(cur_dir, buf_dir) == false then
              close_window_by_bufname(buf_name)
            end
          end
        end
      end
      require("auto-session").setup {
        log_level = "error",
        auto_session_supress_dir = { "~/" },
        pre_save_cmds = {
          close_not_in_working_dir,
        },
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
    "jvgrootveld/telescope-zoxide",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    event = { "VeryLazy" },
  },

  {
    "nvimdev/guard.nvim",
    config = function()
      local ft = require "guard.filetype"
      ft("lua"):fmt {
        cmd = "stylua",
        args = {
          "--search-parent-directories",
          "--",
          "-",
        },
        stdin = true,
      }
      ft("go"):fmt({
        cmd = "gofmt",
        args = {},
        stdin = true,
      }):append {
        cmd = "goimports",
        args = {},
      }

      ft("zig"):fmt "lsp"

      require("guard").setup {
        fmt_on_save = true,
      }
    end,
    event = "VeryLazy",
  },

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
    "nvim-lualine/lualine.nvim",
    requires = { "nvim-tree/nvim-web-devicons", "linrongbin16/lsp-progress.nvim" },
    config = function()
      require "config/lualine"
    end,
    event = "VeryLazy",
  },

  {
    "zhenyangze/vim-bitoai",
    event = "VeryLazy",
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      vim.keymap.set("n", ",xx", function()
        require("trouble").open()
      end)
      vim.keymap.set("n", ",xw", function()
        require("trouble").open "workspace_diagnostics"
      end)
      vim.keymap.set("n", ",xd", function()
        require("trouble").open "document_diagnostics"
      end)
      vim.keymap.set("n", ",xq", function()
        require("trouble").open "quickfix"
      end)
      vim.keymap.set("n", ",xl", function()
        require("trouble").open "loclist"
      end)
      vim.keymap.set("n", ",gR", function()
        require("trouble").open "lsp_references"
      end)
    end,
  },

  {
    "sourcegraph/sg.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        ",as",
        function()
          require("sg.extensions.telescope").fuzzy_search_results()
        end,
        desc = "󰓁 SourceGraph Search",
      },
      { ",al", "<cmd>SourcegraphLink<CR>", desc = "󰓁 Copy SourceGraph URL" },
      { ",aa", "<cmd>CodyAsk<CR>", desc = "󰓁 CodyAsk" },
      { ",ad", "<cmd>CodyDo<CR>", desc = "󰓁 CodyDo" },
    },
  },

  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      require "config/mini"
    end,
    event = "VeryLazy",
  },

  {
    "junnplus/lsp-setup.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim", -- optional
      "williamboman/mason-lspconfig.nvim", -- optional
    },
    -- branch = "inlay-hints",
    config = function()
      require "config/lsp"
    end,
  },
}
