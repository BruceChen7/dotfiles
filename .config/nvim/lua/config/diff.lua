local diffview = require "diffview"
local actions = require("diffview.config").actions

diffview.setup {
  hooks = {
    diff_buf_read = function(bufnr)
      -- vim.api.nvim_buf_del_keymap(bufnr, "n", "<tab>")
      -- local opts = { noremap = true }
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>l", "<c-w>l", opts)
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>j", "<c-w>j", opts)
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>k", "<c-w>k", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>h", "<c-w>h", opts)
    end,
    view_opened = function(view)
      -- dump(view)
      -- bufnr = view.panel.bufid
      -- vim.api.nvim_buf_del_keymap(bufnr, "n", "<tab>")
      -- local opts = { noremap = true }
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>l", "<c-w>l", opts)
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>j", "<c-w>j", opts)
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>k", "<c-w>k", opts)
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>h", "<c-w>h", opts)
    end,
  },
  key_bindings = {
    disable_defaults = true,

    view = {
      ["n"] = actions.select_next_entry, -- Open the diff for the next file
      ["p"] = actions.select_prev_entry, -- Open the diff for the previous file
      -- ["<tab>l"] = actions "focus_entry",
      ["<tab>"] = false,
      ["<s-tab>"] = false,
      -- ["gf"] = actions "goto_file", -- Open the file in a new split in previous tabpage
      ["gf"] = actions.goto_file_split, -- Open the file in a new split
      ["gft"] = actions.goto_file_tab, -- Open the file in a new tabpage
      ["<leader>e"] = actions.focus_files, -- Bring focus to the files panel
      ["<leader>b"] = actions.toggle_files, -- Toggle the files panel.
    },
    file_panel = {
      ["n"] = actions.select_next_entry,
      -- ["<tab>l"] = actions "focus_entry",
      ["p"] = actions.select_prev_entry,
      ["<cr>"] = actions.select_entry,
      ["<up>"] = actions.prev_entry,
      ["<ctrl-j>"] = actions.prev_entry,
      ["<ctrl-k>"] = actions.select_entry, -- Open the diff for the selected entry.
      ["o"] = actions.select_entry,
      ["-"] = actions.toggle_stage_entry, -- Stage / unstage the selected entry.
      ["S"] = actions.stage_all, -- Stage all entries.
      ["U"] = actions.unstage_all, -- Unstage all entries.
      ["X"] = actions.restore_entry, -- Restore entry to the state on the left side.
      ["R"] = actions.refresh_files, -- Update stats and entries in the file list.
      ["gf"] = actions.goto_file,
      ["gss"] = actions.goto_file_split,
      ["gst"] = actions.goto_file_tab,
      ["i"] = actions.listing_style, -- Toggle between 'list' and 'tree' views
      ["f"] = actions.toggle_flatten_dirs, -- Flatten empty subdirectories in tree listing style.
      ["<leader>e"] = actions.focus_files,
      ["<leader>b"] = actions.toggle_files,
      ["<tab>"] = false,
      ["<s-tab>"] = false,
      ["q"] = actions.close,
    },
    file_history_panel = {
      ["g!"] = actions.options, -- Open the option panel
      ["<C-A-d>"] = actions.open_in_diffview, -- Open the entry under the cursor in a diffview
      ["y"] = actions.copy_hash, -- Copy the commit hash of the entry under the cursor
      ["zR"] = actions.open_all_folds,
      ["zM"] = actions.close_all_folds,
      ["j"] = actions.next_entry,
      ["<down>"] = actions.next_entry,
      ["k"] = actions.prev_entry,
      ["<up>"] = actions.prev_entry,
      ["<cr>"] = actions.select_entry,
      ["o"] = actions.select_entry,
      ["<2-LeftMouse>"] = actions.select_entry,
      ["n"] = actions.select_next_entry,
      ["p"] = actions.select_prev_entry,
      ["gf"] = actions.goto_file,
      ["<C-w><C-f>"] = actions.goto_file_split,
      ["<C-w>gf"] = actions.goto_file_tab,
      ["<leader>e"] = actions.focus_files,
      ["<leader>b"] = actions.toggle_files,
    },
    option_panel = {
      -- ["n"] = actions.select,
      -- ["q"] = actions.close,
    },
  },
}
-- open file change list
vim.keymap.set("n", ",df", ":DiffviewOpen<CR>")
vim.keymap.set("n", ",dh", ":DiffviewFileHistory<CR>")
