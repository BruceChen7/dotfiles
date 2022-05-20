local diffview = require "diffview"
local cb = require("diffview.config").diffview_callback

diffview.setup {
  hooks = {
    diff_buf_read = function(bufnr)
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<tab>")
      local opts = { noremap = true }
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>l", "<c-w>l", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>j", "<c-w>j", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>k", "<c-w>k", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>h", "<c-w>h", opts)
    end,
    view_opened = function(view)
      -- dump(view)
      bufnr = view.panel.bufid
      -- vim.api.nvim_buf_del_keymap(bufnr, "n", "<tab>")
      local opts = { noremap = true }
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>l", "<c-w>l", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>j", "<c-w>j", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>k", "<c-w>k", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>h", "<c-w>h", opts)
    end,
  },
  key_bindings = {
    disable_defaults = true,

    view = {
      ["n"] = cb "select_next_entry", -- Open the diff for the next file
      ["p"] = cb "select_prev_entry", -- Open the diff for the previous file
      -- ["<tab>l"] = cb "focus_entry",
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
      -- ["<tab>l"] = cb "focus_entry",
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
      ["q"] = cb "close",
    },
    file_history_panel = {
      ["g!"] = cb "options", -- Open the option panel
      ["<C-A-d>"] = cb "open_in_diffview", -- Open the entry under the cursor in a diffview
      ["y"] = cb "copy_hash", -- Copy the commit hash of the entry under the cursor
      ["zR"] = cb "open_all_folds",
      ["zM"] = cb "close_all_folds",
      ["j"] = cb "next_entry",
      ["<down>"] = cb "next_entry",
      ["k"] = cb "prev_entry",
      ["<up>"] = cb "prev_entry",
      ["<cr>"] = cb "select_entry",
      ["o"] = cb "select_entry",
      ["<2-LeftMouse>"] = cb "select_entry",
      ["n"] = cb "select_next_entry",
      ["p"] = cb "select_prev_entry",
      ["gf"] = cb "goto_file",
      ["<C-w><C-f>"] = cb "goto_file_split",
      ["<C-w>gf"] = cb "goto_file_tab",
      ["<leader>e"] = cb "focus_files",
      ["<leader>b"] = cb "toggle_files",
    },
    option_panel = {
      ["n"] = cb "select",
      ["q"] = cb "close",
    },
  },
}
-- open file change list
vim.keymap.set("n", ",df", ":DiffviewOpen<CR>")
vim.keymap.set("n", ",dh", ":DiffviewFileHistory<CR>")
