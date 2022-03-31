local diffview = require "diffview"
local cb = require("diffview.config").diffview_callback

diffview.setup {
  key_bindings = {
    disable_defaults = true,
    hooks = {
      diff_buf_read = function(bufnr) end,
      view_opened = function(view)
        -- vim.keymap.set("n", "<tab>h", "<c-w>h")
        -- vim.keymap.set("n", "<tab>j", "<c-w>j")
        -- vim.keymap.set("n", "<tab>k", "<c-w>k")
        -- vim.keymap.set("n", "<tab>l", "<c-w>l")
      end,
    },

    view = {
      ["n"] = cb "select_next_entry", -- Open the diff for the next file
      ["p"] = cb "select_prev_entry", -- Open the diff for the previous file
      ["<tab>l"] = cb "focus_entry",
      ["<tab>"] = "",
      ["<s-tab>"] = "",
      -- ["gf"] = cb "goto_file", -- Open the file in a new split in previous tabpage
      ["gf"] = cb "goto_file_split", -- Open the file in a new split
      ["gft"] = cb "goto_file_tab", -- Open the file in a new tabpage
      ["<leader>e"] = cb "focus_files", -- Bring focus to the files panel
      ["<leader>b"] = cb "toggle_files", -- Toggle the files panel.
    },
    file_panel = {
      ["n"] = cb "select_next_entry",
      ["<tab>l"] = cb "focus_entry",
      ["p"] = cb "select_prev_entry",
      ["<cr>"] = cb "select_entry",
      ["<up>"] = cb "prev_entry",
      ["<ctrl-j>"] = cb "prev_entry",
      ["<ctrl-k>"] = cb "select_entry", -- Open the diff for the selected entry.
      ["o"] = cb "select_entry",
      ["-"] = cb "toggle_stage_entry", -- Stage / unstage the selected entry.
      ["S"] = cb "stage_all", -- Stage all entries.
      ["U"] = cb "unstage_all", -- Unstage all entries.
      ["X"] = cb "restore_entry", -- Restore entry to the state on the left side.
      ["R"] = cb "refresh_files", -- Update stats and entries in the file list.
      ["gf"] = cb "goto_file",
      ["gss"] = cb "goto_file_split",
      ["gst"] = cb "goto_file_tab",
      ["i"] = cb "listing_style", -- Toggle between 'list' and 'tree' views
      ["f"] = cb "toggle_flatten_dirs", -- Flatten empty subdirectories in tree listing style.
      ["<leader>e"] = cb "focus_files",
      ["<leader>b"] = cb "toggle_files",
      ["<tab>"] = "",
      ["<s-tab>"] = "",
    },
    option_panel = {
      ["n"] = cb "select",
      ["q"] = cb "close",
    },
  },
}
