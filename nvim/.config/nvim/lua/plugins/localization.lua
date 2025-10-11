-- 输入法和本地化相关插件
return {
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
        set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave", "TermOpen", "BufEnter" },
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

  {
    "piersolenski/import.nvim",
    dependencies = {
      -- One of the following pickers is required:
      -- "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
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

  {
    "shahshlok/vim-coach.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    config = function()
      require("vim-coach").setup()
    end,
    keys = { "<leader>?", "<cmd>VimCoach<cr>", desc = "Vim Coach" },
  },
}