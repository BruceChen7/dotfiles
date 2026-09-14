-- 其他工具和实用程序插件
return {
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

  -- {
  --   "dlyongemallo/diffview.nvim",
  --   config = function()
  --     require "config/diff"
  --   end,
  --   cmd = {
  --     "DiffviewOpen",
  --     "DiffviewClose",
  --     "DiffviewToggleFiles",
  --     "DiffviewFocusFiles",
  --     "DiffviewRefresh",
  --     "DiffviewFileHistory",
  --     "DiffviewLog",
  --   },
  -- },

  {
    "esmuellert/codediff.nvim",
    -- 按需加载：仅在用到 CodeDiff 命令/快捷键时加载（启动省 ~26ms）。
    -- 快捷键与 config/codediff 内注册的保持一致，首次触发即加载插件。
    cmd = { "CodeDiff" },
    keys = {
      { "<leader>gd", "<cmd>CodeDiff<CR>", desc = "CodeDiff changed files" },
      { "<leader>gD", "<cmd>CodeDiff --inline<CR>", desc = "CodeDiff changed files inline" },
      { "<leader>gf", "<cmd>CodeDiff file HEAD<CR>", desc = "CodeDiff current file vs HEAD" },
      { "<leader>gm", "<cmd>CodeDiff main...<CR>", desc = "CodeDiff PR against main" },
      { "<leader>gh", "<cmd>CodeDiff history --reverse<CR>", desc = "CodeDiff recent history" },
      { "<leader>gH", "<cmd>CodeDiff history % --reverse<CR>", desc = "CodeDiff current file history" },
      {
        "<leader>gh",
        ":'<,'>CodeDiff history --reverse<CR>",
        mode = "x",
        desc = "CodeDiff selected lines history",
      },
    },
    config = function()
      require "config/codediff"
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
    "mrcjkb/rustaceanvim",
    version = "^9",
    -- plug is already lazy
    lazy = false,
  },

  {
    "ojroques/nvim-osc52",
    config = function()
      vim.keymap.set("n", "\\c", require("osc52").copy_operator, { expr = true, desc = "copy to clipboard" })
      vim.keymap.set("x", "\\c", require("osc52").copy_visual, { desc = "copy to clipboard" })
    end,
    event = "VeryLazy",
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
    keys = {
      { "\\\\", "<cmd>Marko<cr>", desc = "marks viewer" },
    },
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      require "config/snacks"
    end,
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
}
