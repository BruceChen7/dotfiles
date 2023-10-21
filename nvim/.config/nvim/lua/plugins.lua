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
    "petertriho/cmp-git",
    dependencies = "nvim-lua/plenary.nvim",
    event = "VeryLazy",
    config = function()
      require("cmp_git").setup {}
    end,
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
    -- commit = "6c84bc75c64f778e9f1dcb798ed41c7fcb93b639",
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
  -- {
  --   "camspiers/lens.vim",
  --   config = function()
  --     -- vim.g.lens.disabled_filetypes = { "dapui_stacks", "dapui_scopes" }
  --     vim.g["lens#disabled_filetypes"] = { "dapui_stacks", "dapui_scopes", "dapui_breakpoints" }
  --     vim.g["lens#animate"] = true
  --   end,
  --   -- event = "VeryLazy",
  -- },

  {
    "aznhe21/actions-preview.nvim",
    config = function()
      vim.keymap.set({ "v", "n" }, ",gf", require("actions-preview").code_actions, { desc = "code actions" })
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
        -- build db file in current dir
        -- how to set db_file in ~/.cache/tags/
        -- db_file = "~/.cache/tags/",
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
      require "config/harpoon"
    end,
    event = "VeryLazy",
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
              -- default key is <c-k> which is conflict with telescope.nvim
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
    "jinzhongjia/LspUI.nvim",
    config = function()
      require("LspUI").setup {}
    end,
    event = "LspAttach",
  },

  {
    "Exafunction/codeium.vim",
    config = function()
      if not use_ai() then
        return
      end
      require "config/codeium"
    end,
    event = "InsertEnter",
  },

  {
    "Exafunction/codeium.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      if not use_ai() then
        return
      end
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
          -- local buf_nr = vim.fn.bufnr(buf_name)
          -- local filetype = vim.api.nvim_buf_get_option(buf_nr, "filetype")

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
    "keaising/im-select.nvim",
    config = function()
      local is_linux = function()
        return vim.fn.has "macunix" ~= 1
      end
      local get_im_select = function()
        if is_linux() then
          return "keyboard-us"
        else
          return "com.apple.keylayout.ABC"
        end
      end

      local get_default_command = function()
        if is_linux() then
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
    "stevearc/conform.nvim",
    config = function()
      require("conform").setup {
        formatters_by_ft = {
          lua = { "stylua" },
          go = { "gofmt" },
          zig = { "zigfmt" },
        },
        format_on_save = {
          -- These options will be passed to conform.format()
          timeout_ms = 500,
          lsp_fallback = true,
        },
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
    "willothy/flatten.nvim",
    config = true,
    -- or pass configuration with
    -- opts = {  }
    -- Ensure that it runs first to minimize delay when opening file from terminal
    lazy = false,
    priority = 1001,
  },

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
    "andymass/vim-matchup",
    config = function()
      -- may set any options here
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    config = function()
      require "config/dap"
    end,
    event = "LspAttach",
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
