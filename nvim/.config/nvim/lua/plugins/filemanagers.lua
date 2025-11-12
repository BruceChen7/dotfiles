-- 文件管理器和终端插件
return {
  {
    "stevearc/oil.nvim",
    config = function()
      require "config/oil"
    end,
    -- Optional dependencies
    event = "VeryLazy",
  },
  -- {
  --   "A7Lavinraj/fyler.nvim",
  --   dependencies = { "nvim-mini/mini.icons" },
  --   -- branch = "stable",
  --   config = function()
  --     require "config/fyler"
  --   end,
  --   event = "VeryLazy",
  -- },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require "config/terminal"
    end,
    event = "VeryLazy",
  },

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
    "nvim-mini/mini.nvim",
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
}
