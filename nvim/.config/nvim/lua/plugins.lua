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

local use_ai = function()
  -- print(vim.env.USE_COPILOT)
  return vim.env.USE_COPILOT == "1"
end

require("lazy").setup {
  concurrency = 2,
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "zip",
        "man",
        "rrhelper",
      },
    },
  },

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
    "anuvyklack/hydra.nvim",
    event = "VeryLazy",
    config = function()
      require "config/hydra"
    end,
  },

  -- -- adds vscode-like pictograms to neovim built-in lsp
  { "onsails/lspkind-nvim" },

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
      "hrsh7th/cmp-calc",
    },
    -- event = "InsertEnter",
    config = function()
      require "config/cmp"
      require "config/md_source"
    end,
    branch = "main",
    -- https://www.reddit.com/r/neovim/comments/162q5ca/whats_your_favorite_unknown_nvimvim_plugin/
    -- commit = "6c84bc75c64f778e9f1dcb798ed41c7fcb93b639",
    ft = { "go", "lua", "python", "zig", "rust" },
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

  {
    "aznhe21/actions-preview.nvim",
    config = function()
      vim.keymap.set({ "v", "n" }, "\\gf", require("actions-preview").code_actions, { desc = "code actions" })
    end,
    event = "LspAttach",
  },

  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = "VeryLazy",
    config = function()
      require "config/text_obj"
    end,
  },
  -- Smartly select the inner part of texts
  {
    "sustech-data/wildfire.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("wildfire").setup()
    end,
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
    -- branch = "nightly",
  },

  {
    "nvim-lua/lsp_extensions.nvim",
    event = "VeryLazy",
  },

  {
    "dhananjaylatkar/cscope_maps.nvim",
    dependencies = {
      -- "nvim-telescope/telescope.nvim", -- optional [for picker="telescope"]
      "nvim-tree/nvim-web-devicons", -- optional [for devicons in telescope or fzf]
    },
    opts = {
      skip_input_prompt = true,
      cscope = {
        exec = "gtags-cscope",
        -- build db file in current dir
        -- how to set db_file in ~/.cache/tags/
        -- db_file = "~/.cache/tags/",
        -- picker = "telescope",
        skip_picker_for_single_result = true,
        db_build_cmd_args = { "-bqkv" },
      },
    },
    -- ft = { "c", "cpp", "zig",  },
    event = "VeryLazy",
  },

  {
    "mrcjkb/rustaceanvim",
    version = "^4",
    -- plug is already lazy
    lazy = false,
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
    event = "LspAttach",
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
      require "config/harpoon"
    end,
    event = "VeryLazy",
    commit = "ccae1b9bec717ae284906b0bf83d720e59d12b91",
  },

  -- colorscheme
  { "folke/tokyonight.nvim" },

  {
    "gennaro-tedesco/nvim-peekup",
  },

  {
    "ptdewey/yankbank-nvim",
    config = function()
      require("yankbank").setup {
        max_entries = 20,
        num_behavior = "prefix",
      }
      vim.keymap.set("n", "<leader>y", "<cmd>YankBank<CR>", { noremap = true, desc = "yank history list" })
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
          definition = false,
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
    commit = "13d25ad8bd55aa34cc0aa3082e78a4157c401346",
    -- 手动打开，否则对大量pb生成的go文件进行reference，implementation的时候，很慢
    cmd = "LspLensOn",
  },

  {
    "ojroques/nvim-osc52",
    config = function()
      vim.keymap.set("n", "\\c", require("osc52").copy_operator, { expr = true })
      vim.keymap.set("x", "\\c", require("osc52").copy_visual)
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
          keys = {},
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

  {
    "supermaven-inc/supermaven-nvim",
    config = function()
      require("supermaven-nvim").setup {
        -- disable_keymaps = true,
        keymaps = {
          accept_suggestion = "<C-y>",
          clear_suggestion = "<C-]",
          accept_word = "<C-j>",
        },
        -- color = {
        --   suggestion_color = "#ffffff",
        --   cterm = 244,
        -- },
      }
    end,
    event = "VeryLazy",
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
    "keaising/im-select.nvim",
    config = function()
      local utils = require "utils"
      local get_im_select = function()
        if not utils.is_mac() then
          return "keyboard-us"
        else
          return "com.apple.keylayout.ABC"
        end
      end

      local get_default_command = function()
        if not utils.is_mac() then
          return "fcitx5-remote"
        else
          return "im-select"
        end
      end

      if not use_ai() then
        return
      end

      -- 用来自动切换输入法
      require("im_select").setup {
        default_im_select = get_im_select(),
        default_command = get_default_command(),
        set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },

        -- Restore the previous used input method state when the following events
        -- are triggered, if you don't want to restore previous used im in Insert mode,
        -- e.g. deprecated `disable_auto_restore = 1`, just let it empty
        -- as `set_previous_events = {}`
        set_previous_events = { "InsertEnter" },

        -- Show notification about how to install executable binary when binary missed
        keep_quiet_on_no_binary = false,

        -- Async run `default_command` to switch IM or not
        async_switch_im = true,
      }
    end,
    event = "InsertEnter",
  },

  -- {
  --   "Exafunction/codeium.vim",
  --   config = function()
  --     if not use_ai() then
  --       return
  --     end
  --     require "config/codeium"
  --   end,
  --   event = "InsertEnter",
  -- },

  {
    "robitx/gp.nvim",
    config = function()
      require "config/gp"
    end,
    event = "VeryLazy",
  },

  -- find files
  {
    "ibhagwan/fzf-lua",
    -- optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require "config/fzf"
    end,
    event = "VeryLazy",
  },

  -- format code
  {
    "stevearc/conform.nvim",
    config = function()
      require("conform").setup {
        formatters_by_ft = {
          lua = { "stylua" },
          go = { "gofmt", "goimports" },
          zig = { "zigfmt" },
          markdown = { "autocorrect" },
          typst = { "autocorrect" },
          python = { "ruff_format" },
        },

        format_on_save = function(bufnr)
          return { timeout_ms = 500, lsp_fallback = true }
        end,
        formatters = {
          autocorrect = {
            command = "autocorrect",
            args = { "--stdin", "$FILENAME" },
            stdin == true,
          },
        },
      }
    end,
    event = "VeryLazy",
  },

  -- {
  --   "nvim-lualine/lualine.nvim",
  --   requires = { "nvim-tree/nvim-web-devicons", "linrongbin16/lsp-progress.nvim" },
  --   config = function()
  --     require "config/lualine"
  --   end,
  --   event = "VeryLazy",
  -- },

  {
    "zhenyangze/vim-bitoai",
    event = "VeryLazy",
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      vim.keymap.set("n", "\\xx", function()
        require("trouble").open()
      end, { desc = "current Diagnostics" })
      vim.keymap.set("n", "\\xw", function()
        require("trouble").open "workspace_diagnostics"
      end, { desc = "Workspace Diagnostics" })
      vim.keymap.set("n", "\\xd", function()
        require("trouble").open "document_diagnostics"
      end, { desc = "Document Diagnostics" })
    end,
  },

  -- "Preview command results with `:Norm`"
  {
    "smjonas/live-command.nvim",
    -- live-command supports semantic versioning via tags
    -- tag = "1.*",
    config = function()
      require("live-command").setup {
        commands = {
          Norm = { cmd = "norm" },
        },
      }
    end,
  },

  -- {
  --   "akinsho/bufferline.nvim",
  --   dependencies = "nvim-tree/nvim-web-devicons",
  --   config = function()
  --     require "config/bufferline"
  --   end,
  --   -- event = "VeryLazy",
  -- },

  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      require "config/mini"
    end,
    event = "VeryLazy",
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

  -- Make the cursor move in the middle of camel words
  -- {
  --   "chrisgrieser/nvim-spider",
  --   event = "VeryLazy",
  --   config = function()
  --     vim.keymap.set({ "n", "o", "x" }, "w", "<cmd>lua require('spider').motion('w')<CR>", { desc = "Spider-w" })
  --     vim.keymap.set({ "n", "o", "x" }, "e", "<cmd>lua require('spider').motion('e')<CR>", { desc = "Spider-e" })
  --     vim.keymap.set({ "n", "o", "x" }, "b", "<cmd>lua require('spider').motion('b')<CR>", { desc = "Spider-b" })
  --     vim.keymap.set("i", "<C-f>", "<Esc>l<cmd>lua require('spider').motion('w')<CR>i")
  --     vim.keymap.set("i", "<C-b>", "<Esc><cmd>lua require('spider').motion('b')<CR>i")
  --   end,
  -- },

  -- use xmake
  {
    "Mythos-404/xmake.nvim",
    lazy = true,
    event = "BufReadPost xmake.lua",
    config = true,
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
  },

  -- not working yet
  -- becuse of no valid access token
  -- {
  --   "zbirenbaum/copilot.lua",
  --   event = "InsertEnter",
  --   config = function()
  --     if not use_ai() then
  --       return
  --     end
  --     require("copilot").setup {
  --       panel = {
  --         enabled = false,
  --       },
  --       suggestion = {
  --         enabled = false,
  --       },
  --     }
  --   end,
  -- },

  -- {
  --   "zbirenbaum/copilot-cmp",
  --   dependencies = { "zbirenbaum/copilot.lua" },
  --   config = function()
  --     if not use_ai() then
  --       return
  --     end
  --     require("copilot_cmp").setup()
  --   end,
  -- },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 500
    end,
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require "config/dap"
    end,
    event = "LspAttach",
  },

  {
    "nvim-pack/nvim-spectre",
    config = function()
      vim.keymap.set("n", "<leader>S", '<cmd>lua require("spectre").toggle()<CR>', {
        desc = "Toggle Spectre",
      })
      vim.keymap.set("n", "<leader>sw", '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', {
        desc = "Search current word",
      })
      vim.keymap.set("v", "<leader>sw", '<esc><cmd>lua require("spectre").open_visual()<CR>', {
        desc = "Search current word",
      })
      vim.keymap.set("n", "<leader>sp", '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>', {
        desc = "Search on current file",
      })
      require("spectre").setup {
        mapping = {
          ["run_current_replace"] = {
            map = "<leader>rc",
            cmd = "<cmd>lua require('spectre.actions').run_current_replace()<CR>",
            desc = "replace current line",
          },
          ["run_replace"] = {
            map = "<leader>rr",
            cmd = "<cmd>lua require('spectre.actions').run_replace()<CR>",
            desc = "replace all",
          },
        },
      }
    end,
    event = "VeryLazy",
  },

  {
    "sainnhe/gruvbox-material",
  },
  -- {
  --   "dgagn/diagflow.nvim",
  --   event = "LspAttach",
  --   config = function()
  --     require("diagflow").setup()
  --   end,
  -- },

  -- Jump across files to the last edited location
  {
    "bloznelis/before.nvim",
    config = function()
      local before = require "before"
      before.setup()

      -- Jump to previous entry in the edit history
      vim.keymap.set("n", "<space>g;", before.jump_to_last_edit, { desc = "Jump to last edit position" })

      -- Jump to next entry in the edit history
      vim.keymap.set("n", "<space>g,", before.jump_to_next_edit, { desc = "Jump to next edit position" })

      -- Look for previous edits in quickfix list
      vim.keymap.set("n", "<space>gq", before.show_edits_in_quickfix, { desc = "Show edits in quickfix" })

      -- Look for previous edits in telescope (needs telescope, obviously)
      -- vim.keymap.set("n", "<space>", before.show_edits_in_telescope, {})
    end,
    event = "VeryLazy",
  },
  -- https://www.reddit.com/r/neovim/comments/1c747ns/treepairs_a_tiny_plugin_that_makes_work_properly/
  -- {
  --   "yorickpeterse/nvim-tree-pairs",
  --   config = function()
  --     require("tree-pairs").setup()
  --   end,
  --   event = "VeryLazy",
  -- },

  -- https://www.reddit.com/r/neovim/comments/1ca3rm8/shoutout_to_andrewferrierdebugprintnvim_add/
  {
    "andrewferrier/debugprint.nvim",
    opts = {},
    dependencies = {
      "echasnovski/mini.nvim", -- Needed to enable :ToggleCommentDebugPrints for NeoVim <= 0.9
      "nvim-treesitter/nvim-treesitter", -- Needed to enable treesitter for NeoVim 0.8
    },
    -- Remove the following line to use development versions,
    -- not just the formal releases
    version = "*",
    event = "VeryLazy",
  },

  {
    "stevearc/oil.nvim",
    config = function()
      require "config/oil"
    end,
    -- Optional dependencies
    dependencies = { "nvim-tree/nvim-web-devicons" },
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
    event = "VeryLazy",
  },
}
