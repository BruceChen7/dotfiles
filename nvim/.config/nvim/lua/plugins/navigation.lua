-- 文件管理和终端相关插件
return {
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
