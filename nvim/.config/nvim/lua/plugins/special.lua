-- 特殊用途插件
return {
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
    "skywind3000/gutentags_plus",
    -- event = "VeryLazy",
  },

  {
    "tpope/vim-fugitive",
    config = function()
      require "config/fugtive"
    end,
    event = "VeryLazy",
    keys = {
      { "\\\\\\", "<cmd>Marko<cr>", desc = "vim marks" },
    },
  },

  -- {
  --   "akinsho/git-conflict.nvim",
  --   version = "*",
  --   config = function()
  --     require("git-conflict").setup {}
  --   end,
  --   event = "VeryLazy",
  -- },
  -- {
  --   "lambdalisue/vim-fern",
  --   config = function()
  --     require "config/fern"
  --   end,
  --   event = "VeryLazy",
  -- },
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
    "nvim-mini/mini.icons",
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
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
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
    "Mythos-404/xmake.nvim",
    lazy = true,
    event = "BufReadPost xmake.lua",
    config = true,
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
  },

  {
    "Kurama622/llm.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
    cmd = { "LLMSessionToggle", "LLMSelectedTextHandler", "LLMAppHandler" },
    config = function()
      require "config/llm"
    end,
  },
}