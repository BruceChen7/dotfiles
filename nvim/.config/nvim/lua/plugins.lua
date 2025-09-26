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
    "skywind3000/vim-gutentags",
    config = function()
      require "config/gtags"
    end,
    event = "VeryLazy",
  },

  { "skywind3000/vim-preview" },
  { "skywind3000/vim-quickui" },
  { "skywind3000/asynctasks.vim" },
  {
    "skywind3000/asyncrun.vim",
  },

  {
    "Goose97/timber.nvim",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("timber").setup {
        -- Configuration here, or leave empty to use defaults
      }
    end,
  },

  {
    "skywind3000/gutentags_plus",
    -- event = "VeryLazy",
  },

  {
    "saghen/blink.cmp",
    event = "BufReadPre",
    -- event = "LspAttach",
    version = "v1.*", -- REQUIRED release tag to download pre-built binaries
    build = "cargo build --release",
    dependencies = {
      "Kaiser-Yang/blink-cmp-avante",
      "archie-judd/blink-cmp-words",
    },
    opts = {
      appearance = {
        -- Sets the fallback highlight groups to nvim-cmp's highlight groups
        -- Useful for when your theme doesn't support blink.cmp
        -- will be removed in a future release
        use_nvim_cmp_as_default = true,
        -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = "mono",
      },
      completion = {
        keyword = { range = "full" },
        accept = { auto_brackets = { enabled = true } },
        menu = {
          auto_show = function()
            return vim.bo.buftype ~= "prompt" and vim.b.completion ~= false and vim.bo.filetype ~= "TelescopePrompt"
          end,
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        -- ghost_text = { enabled = true },
        list = {
          selection = {
            preselect = false,
            auto_insert = true,
          },
        },
      },
      sources = {
        -- Remove 'buffer' if you don't want text completions, by default it's only enabled when LSP returns no items
        default = { "avante", "lsp", "path", "snippets", "buffer" },
        providers = {
          avante = {
            module = "blink-cmp-avante",
            name = "Avante",
            opts = {
              -- options for blink-cmp-avante
            },
          },
          thesaurus = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.thesaurus",
            -- All available options
            opts = {
              -- A score offset applied to returned items.
              -- By default the highest score is 0 (item 1 has a score of -1, item 2 of -2 etc..).
              score_offset = 0,

              -- Default pointers define the lexical relations listed under each definition,
              -- see Pointer Symbols below.
              -- Default is as below ("antonyms", "similar to" and "also see").
              definition_pointers = { "!", "&", "^" },
            },
          },

          -- Use the dictionary source
          dictionary = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.dictionary",
            -- All available options
            opts = {
              -- The number of characters required to trigger completion.
              -- Set this higher if completion is slow, 3 is default.
              dictionary_search_threshold = 3,

              -- See above
              score_offset = 0,

              -- See above
              definition_pointers = { "!", "&", "^" },
            },
          },
        },
        per_filetype = {
          text = { "dictionary" },
          markdown = { "thesaurus" },
          gitcommit = { "dictionary", "buffer", "path" },
          AvanteInput = { "dictionary", "buffer", "path" },
        },
      },
      cmdline = {
        enabled = true,
        -- keymap = { preset = "cmdline" },
        -- https://cmp.saghen.dev/modes/cmdline.html
        keymap = {
          ["<Tab>"] = {
            function(cmp)
              if cmp.is_ghost_text_visible() and not cmp.is_menu_visible() then
                return cmp.accept()
              end
            end,
            "show_and_insert",
            "select_next",
          },
          ["<S-Tab>"] = { "show_and_insert", "select_prev" },

          ["<C-j>"] = { "select_next" },
          ["<C-k>"] = { "select_prev" },

          ["<C-y>"] = { "select_and_accept" },
          ["<C-e>"] = { "cancel" },
        },
        sources = function()
          local type = vim.fn.getcmdtype()
          -- Search forward and backward
          if type == "/" or type == "?" then
            return { "buffer" }
          end
          -- Commands
          if type == ":" or type == "@" then
            return { "cmdline" }
          end
          return {}
        end,
      },

      keymap = {
        -- ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
        ["<C-y>"] = { "fallback" },
        ["<enter>"] = { "select_and_accept", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
      signature = {
        enabled = true,
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
    event = "VeryLazy",
    version = "v1.*",
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

  -- https://github.com/ravsii/tree-sitter-d2
  -- for d2 syntax highlight
  {
    "ravsii/tree-sitter-d2",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    build = "make nvim-install",
    event = "VeryLazy",
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
    "mrcjkb/rustaceanvim",
    version = "^4",
    -- plug is already lazy
    lazy = false,
  },
  --
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
    -- dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lsp-progress").setup()
    end,
    event = "LspAttach",
  },

  {
    "sindrets/diffview.nvim",
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

  -- Show how many words can match after pressing *
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

  -- colorscheme
  -- { "folke/tokyonight.nvim" },

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

  -- {
  --   "akinsho/git-conflict.nvim",
  --   version = "*",
  --   config = function()
  --     require("git-conflict").setup {}
  --   end,
  --   event = "VeryLazy",
  -- },

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
    -- commit = "13d25ad8bd55aa34cc0aa3082e78a4157c401346",
    -- 手动打开，否则对大量pb生成的go文件进行reference，implementation的时候，很慢
    cmd = "LspLensOn",
  },

  -- {
  --   "lambdalisue/vim-fern",
  --   config = function()
  --     require "config/fern"
  --   end,
  --   event = "VeryLazy",
  -- },
  --
  {
    "tpope/vim-fugitive",
    config = function()
      require "config/fugtive"
    end,
    event = "VeryLazy",
    keys = {
      { "\\\\", "<cmd>Marko<cr>", desc = "vim marks" },
    },
  },

  {
    "ojroques/nvim-osc52",
    config = function()
      vim.keymap.set("n", "\\c", require("osc52").copy_operator, { expr = true, desc = "copy to clipboard" })
      vim.keymap.set("x", "\\c", require("osc52").copy_visual, { desc = "copy to clipboard" })
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

  -- skip to inner bracket
  {
    "abecodes/tabout.nvim",
    config = function()
      require "config/tabout"
    end,
    dependencies = {
      -- "/nvim-cmp", -- Autocompletion plugin
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
          -- return "im-select"
          --  check macism has been installed
          local macism_exists = vim.fn.system "which macism"
          if macism_exists == "" then
            vim.notify "macism not installed"
            return
          end
          return "macism"
        end
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
    -- event = "InsertEnter",
  },

  -- amongst your other plugins
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require "config/terminal"
    end,
    event = "VeryLazy",
  },

  {
    "Exafunction/codeium.vim",
    config = function()
      require "config/codeium"
    end,
    event = "InsertEnter",
  },

  {
    "robitx/gp.nvim",
    config = function()
      require "config/gp"
    end,
    event = "BufReadPre",
  },

  -- find files
  -- {
  --   "ibhagwan/fzf-lua",
  --   -- optional for icon support
  --   -- dependencies = { "nvim-tree/nvim-web-devicons" },
  --   config = function()
  --     require "config/fzf"
  --   end,
  --   event = "VeryLazy",
  --   -- commit = "48f8a85291e56309087960cc9918d02e6131db3b",
  -- },

  -- {
  --   "leath-dub/snipe.nvim",
  --   config = function()
  --     local snipe = require "snipe"
  --     snipe.setup {
  --       hints = {
  --         dictionary = "adflewcmpghio",
  --       },
  --     }
  --     vim.keymap.set("n", "gb", snipe.create_buffer_menu_toggler(), { desc = "show buffer menu" })
  --   end,
  --   event = "VeryLazy",
  -- },

  -- format code
  {
    "stevearc/conform.nvim",
    config = function()
      require("conform").setup {
        -- log_level = vim.log.levels.TRACE,
        formatters_by_ft = {
          lua = { "stylua" },
          go = { "gofmt", "goimports" },
          zig = { "zigfmt" },
          markdown = { "autocorrect", "trim_empty_lines" },
          typst = { "autocorrect" },
          python = { "ruff" },
        },

        format_on_save = function(bufnr)
          return { timeout_ms = 1000, lsp_fallback = true }
        end,
        formatters = {
          autocorrect = {
            command = "autocorrect",
            args = { "--stdin", "$FILENAME" },
            -- args = { "$FILENAME" },
            -- stdin == true,
          },
          -- `filename` is original file content
          -- 这里不能使用`$FILENAME`，因为`$FILENAME`是当前文件的内容(上次保存的内容)
          -- 你需要的是修改后的内容
          trim_empty_lines = {
            command = "awk",
            args = { '/^$/{n=n RS}; /./{printf "%s%s%s",n,$0,RS; n=""}' },
          },
        },
      }
    end,
    event = "VeryLazy",
  },

  -- { "zenbones-theme/zenbones.nvim" },
  -- -- Optionally install Lush. Allows for more configuration or extending the colorscheme
  -- -- If you don't want to install lush, make sure to set g:zenbones_compat = 1
  -- -- In Vim, compat mode is turned on as Lush only works in Neovim.
  -- { "rktjmp/lush.nvim" },
  {
    "folke/trouble.nvim",
    opts = {}, -- for default options, refer to the configuration section for custom setup.
    cmd = "Trouble",
    keys = {
      {
        "\\xx",
        "<cmd>Trouble diagnostics toggle<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "\\xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "\\cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "\\cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "\\xL",
        "<cmd>Trouble loclist toggle<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "\\xQ",
        "<cmd>Trouble qflist toggle<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
  },

  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    config = function()
      require("tiny-inline-diagnostic").setup()
      require("tiny-inline-diagnostic").disable()
      vim.keymap.set("n", "\\td", function()
        require("tiny-inline-diagnostic").toggle()
      end, { desc = "Toggle Tiny Inline Diagnostic" })
    end,
  },

  {
    "carbon-steel/detour.nvim",
    config = function()
      vim.keymap.set("n", "<c-w><enter>", "<cmd>Detour<cr>")
      vim.keymap.set("n", "<c-w>.", "<cmd>DetourCurrentWindow<cr>")
    end,
    event = "VeryLazy",
  },

  -- https://github.com/echasnovski/mini.nvim/issues/1007
  {
    "echasnovski/mini.icons",
    lazy = true,
    opts = {},
    config = function()
      require("mini.icons").setup()
    end,
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
    event = "VeryLazy",
  },

  {
    "ravitemer/mcphub.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for Job and HTTP requests
    },
    -- comment the following line to ensure hub will be ready at the earliest
    cmd = "MCPHub", -- lazy load by default
    build = "npm install -g mcp-hub@latest", -- Installs required mcp-hub npm module
    -- uncomment this if you don't want mcp-hub to be available globally or can't use -g
    -- build = "bundled_build.lua",  -- Use this and set use_bundled_binary = true in opts  (see Advanced configuration)
    config = function()
      require "config/mcphub"
    end,
  },
  -- {
  --   "yetone/avante.nvim",
  --   lazy = false,
  --   build = "make BUILD_FROM_SOURCE=true",
  --   -- version = "v0.*",
  --   dependencies = {
  --     -- "nvim-tree/nvim-web-devicons",
  --     "echasnovski/mini.nvim",
  --     "stevearc/dressing.nvim",
  --     "nvim-lua/plenary.nvim",
  --     {
  --       "grapp-dev/nui-components.nvim",
  --       dependencies = {
  --         "MunifTanjim/nui.nvim",
  --       },
  --     },
  --   },
  --   config = function()
  --     require "config/avante"
  --   end,
  -- },
  --
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
    event = "VeryLazy",
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
    "willothy/flatten.nvim",
    config = true,
    -- or pass configuration with
    -- opts = {  }
    -- Ensure that it runs first to minimize delay when opening file from terminal
    lazy = false,
    priority = 1001,
  },

  -- use xmake
  {
    "Mythos-404/xmake.nvim",
    lazy = true,
    event = "BufReadPost xmake.lua",
    config = true,
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "igorlfs/nvim-dap-view" },
      { "theHamsta/nvim-dap-virtual-text" },
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
  -- Lazy
  {
    "piersolenski/import.nvim",
    dependencies = {
      -- One of the following pickers is required:
      -- "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
      -- 'ibhagwan/fzf-lua',
    },
    opts = {
      picker = "snacks",
    },
    keys = {
      {
        "\\i",
        function()
          require("import").pick()
        end,
        desc = "Import",
      },
    },
  },

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

  {
    "stevearc/oil.nvim",
    config = function()
      require "config/oil"
    end,
    -- Optional dependencies
    event = "VeryLazy",
  },
  {
    "williamboman/mason-lspconfig.nvim",
    -- version = "v1.*",
    event = "VeryLazy",
  },

  {
    "junnplus/lsp-setup.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim", -- optional
      -- :LspInstall command provided by mason-lspconfig
      -- "williamboman/mason-lspconfig.nvim", -- optional
    },
    -- branch = "inlay-hints",
    config = function()
      require "config/lsp"
    end,
    event = "VeryLazy",
    -- lazy = true,
  },

  { "meznaric/key-analyzer.nvim", opts = {} },

  {
    "Kurama622/llm.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
    -- cmd = { "LLMSesionToggle", "LLMSelectedTextHandler" },
    event = "VeryLazy",
    config = function()
      require "config/llm"
    end,
  },

  -- colorscheme
  { "yorumicolors/yorumi.nvim" },

  -- used to help you learn vim most common commands
  {
    "shahshlok/vim-coach.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    config = function()
      require("vim-coach").setup()
    end,
    keys = {
      { "<leader>?", "<cmd>VimCoach<cr>", desc = "Vim Coach" },
    },
  },

  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      terminal_cmd = "ccr code", -- Point to local installation
    },
    config = true,
    keys = {
      -- Your keymaps here
      -- { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>aS",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
      },
      -- Diff management
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      file_types = { "markdown", "Avante" },
      code = {
        sign = false,
        style = "normal",
      },
    },
    ft = { "markdown", "Avante" },
    version = "v8.*",
  },

  {
    "developedbyed/marko.nvim",
    config = function()
      require("marko").setup {
        width = 100,
        height = 100,
        border = "rounded",
        title = " Marks ",
      }
    end,
    event = "VeryLazy",
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      bigfile = { enabled = false },
      picker = { enabled = true },
      image = { enabled = true },
      terminal = { enabled = true },
    },

    keys = {
      -- files
      {
        "<m-o>",
        function()
          Snacks.picker.smart {
            multi = { "recent", "buffers", "files" },
          }
        end,
        desc = "Smart Find Files",
      },
      {
        "<m-b>",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
      },
      {
        "<c-p>",
        function()
          Snacks.picker.files()
        end,
        desc = "Find Files",
      },

      {
        "<space>tg",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep",
      },
      {
        "<leader>ch",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command History",
      },
      -- find
      {
        "<leader>fp",
        function()
          Snacks.picker.projects()
        end,
        desc = "Projects",
      },
      {

        "<leader>fr",
        function()
          Snacks.picker.recent()
        end,
        desc = "Recent",
      },
      -- git
      {
        "\\gb",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Git Branches",
      },

      -- Grep
      {
        "<leader>sb",
        function()
          Snacks.picker.lines()
        end,
        desc = "Buffer Lines",
      },
      {
        "<leader>sB",
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = "Grep Open Buffers",
      },
      {
        "<leader>sg",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep",
      },
      {
        "g1",
        function()
          Snacks.picker.grep_word()
        end,
        desc = "Visual selection or word",
        mode = { "n", "x" },
      },

      -- search
      {
        "<leader>s/",
        function()
          Snacks.picker.search_history()
        end,
        desc = "Search History",
      },
      {
        "\\sa",
        function()
          Snacks.picker.autocmds()
        end,
        desc = "Autocmds",
      },
      {
        "<leader>sb",
        function()
          Snacks.picker.lines()
        end,
        desc = "Buffer Lines",
      },
      {
        "<leader>sd",
        function()
          Snacks.picker.diagnostics()
        end,
        desc = "Diagnostics",
      },
      {
        "<leader>sD",
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = "Buffer Diagnostics",
      },
      {
        "<leader>sh",
        function()
          Snacks.picker.help()
        end,
        desc = "Help Pages",
      },
      {
        "<leader>sH",
        function()
          Snacks.picker.highlights()
        end,
        desc = "Highlights",
      },
      {
        "<leader>si",
        function()
          Snacks.picker.icons()
        end,
        desc = "Icons",
      },
      {
        "<leader>sj",
        function()
          Snacks.picker.jumps()
        end,
        desc = "Jumps",
      },
      {
        "<leader>sk",
        function()
          Snacks.picker.keymaps()
        end,
        desc = "Keymaps",
      },
      {
        "<leader>sl",
        function()
          Snacks.picker.loclist()
        end,
        desc = "Location List",
      },
      {
        "<leader>sm",
        function()
          Snacks.picker.marks()
        end,
        desc = "Marks",
      },
      {
        "<leader>sM",
        function()
          Snacks.picker.man()
        end,
        desc = "Man Pages",
      },
      {
        "<leader>sp",
        function()
          Snacks.picker.lazy()
        end,
        desc = "Search for Plugin Spec",
      },
      {
        "<leader>sq",
        function()
          Snacks.picker.qflist()
        end,
        desc = "Quickfix List",
      },
      {
        "<leader>tr",
        function()
          Snacks.picker.resume()
        end,
        desc = "Resume",
      },
      {
        "<leader>su",
        function()
          Snacks.picker.undo()
        end,
        desc = "Undo History",
      },
      {
        "<leader>uC",
        function()
          Snacks.picker.colorschemes()
        end,
        desc = "Colorschemes",
      },

      -- LSP
      {
        "gd",
        function()
          Snacks.picker.lsp_definitions()
        end,
        desc = "Goto Definition",
      },
      {
        "gD",
        function()
          Snacks.picker.lsp_declarations()
        end,
        desc = "Goto Declaration",
      },
      {
        "grr",
        function()
          Snacks.picker.lsp_references()
        end,
        nowait = true,
        desc = "References",
      },
      {
        "\\gi",
        function()
          Snacks.picker.lsp_implementations()
        end,
        desc = "Goto Implementation",
      },
      {
        "\\gy",
        function()
          Snacks.picker.lsp_type_definitions()
        end,
        desc = "Goto T[y]pe Definition",
      },
      {
        "<c-\\>",
        function()
          Snacks.terminal()
        end,
        desc = "Terminal",
        mode = { "n", "t" },
      },
      {
        "gs",
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = "LSP Symbols",
      },
      {
        "<leader>sS",
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = "LSP Workspace Symbols",
      },
      {
        "<leader>gB",
        function()
          Snacks.gitbrowse()
        end,
        desc = "Git Browse",
        mode = { "n", "v" },
      },
      {
        "<leader>lg",
        function()
          Snacks.lazygit()
        end,
        desc = "Lazygit",
      },
      -- {
      --   "]]",
      --   function()
      --     Snacks.words.jump(vim.v.count1)
      --   end,
      --   desc = "Next Reference",
      --   mode = { "n", "t" },
      -- },
      -- {
      --   "[[",
      --   function()
      --     Snacks.words.jump(-vim.v.count1)
      --   end,
      --   desc = "Prev Reference",
      --   mode = { "n", "t" },
      -- },
      {
        "<leader>N",
        desc = "Neovim News",
        function()
          Snacks.win {
            file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
            width = 0.6,
            height = 0.6,
            wo = {
              spell = false,
              wrap = false,
              signcolumn = "yes",
              statuscolumn = " ",
              conceallevel = 3,
            },
          }
        end,
      },
    },
  },
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      -- Recommended for better prompt input, and required to use `opencode.nvim`'s embedded terminal — otherwise optional
      { "folke/snacks.nvim", opts = { input = { enabled = true } } },
    },
    config = function()
      vim.g.opencode_opts = {
        -- Your configuration, if any — see `lua/opencode/config.lua`
      }

      -- Required for `opts.auto_reload`
      vim.opt.autoread = true
      -- Recommended keymaps
      vim.keymap.set("n", "<leader>ot", function()
        require("opencode").toggle()
      end, { desc = "Toggle" })
      vim.keymap.set("n", "<leader>oA", function()
        require("opencode").ask()
      end, { desc = "Ask" })
      vim.keymap.set("n", "<leader>oa", function()
        require("opencode").ask "@cursor: "
      end, { desc = "Ask about this" })
      vim.keymap.set("v", "<leader>oa", function()
        require("opencode").ask "@selection: "
      end, { desc = "Ask about selection" })
      vim.keymap.set("n", "<leader>o+", function()
        require("opencode").append_prompt "@buffer"
      end, { desc = "Add buffer to prompt" })
      vim.keymap.set("v", "<leader>o+", function()
        require("opencode").append_prompt "@selection"
      end, { desc = "Add selection to prompt" })
      vim.keymap.set("n", "<leader>on", function()
        require("opencode").command "session_new"
      end, { desc = "New session" })
      vim.keymap.set("n", "<leader>oy", function()
        require("opencode").command "messages_copy"
      end, { desc = "Copy last response" })
      vim.keymap.set("n", "<S-C-u>", function()
        require("opencode").command "messages_half_page_up"
      end, { desc = "Messages half page up" })
      vim.keymap.set("n", "<S-C-d>", function()
        require("opencode").command "messages_half_page_down"
      end, { desc = "Messages half page down" })
      vim.keymap.set({ "n", "v" }, "<leader>os", function()
        require("opencode").select()
      end, { desc = "Select prompt" })

      -- Example: keymap for custom prompt
      vim.keymap.set("n", "<leader>oe", function()
        require("opencode").prompt "Explain @cursor and its context"
      end, { desc = "Explain this code" })
    end,
  },

  {
    "aaronik/treewalker.nvim",
    opts = {
      highlight = true, -- Whether to briefly highlight the node after jumping to it
      highlight_duration = 250, -- How long should above highlight last (in ms)
    },
    config = function()
      vim.keymap.set("n", "\\wj", "<cmd>Treewalker Down<CR>", { noremap = true, desc = "treewalker down" })
      vim.keymap.set("n", "\\wk", "<cmd>Treewalker Up<CR>", { noremap = true, desc = "Treewalker up" })
      vim.keymap.set("n", "\\wh", "<cmd>Treewalker Left<CR>", { noremap = true, desc = "treewalker left" })
      vim.keymap.set("n", "\\wl", "<cmd>Treewalker Right<CR>", { noremap = true, desc = "treewalker right" })
    end,
  },
}
