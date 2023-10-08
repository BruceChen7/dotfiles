local diffview = require "diffview"
local actions = require("diffview.config").actions

diffview.setup {
  diff_binaries = false,
  use_icons = true,
  icons = { -- Only applies when use_icons is true.
    folder_closed = "",
    folder_open = "",
  },
  signs = {
    fold_closed = "",
    fold_open = "",
  },
  hooks = {
    diff_buf_read = function(bufnr)
      -- vim.api.nvim_buf_del_keymap(bufnr, "n", "<tab>")
      local opts = { noremap = true, silent = true }
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>l", "<c-w>l", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>j", "<c-w>j", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>k", "<c-w>k", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>h", "<c-w>h", opts)
    end,
    view_opened = function(view)
      -- dump(view)
      local opts = { noremap = true, silent = true }
      local bufnr = view.panel.bufid
      -- vim.api.nvim_buf_del_keymap(bufnr, "n", "<tab>", opts)
      local opts = { noremap = true }
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>l", "<c-w>l", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>j", "<c-w>j", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>k", "<c-w>k", opts)
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<tab>h", "<c-w>h", opts)
    end,
  },
  keymaps = {
    disable_defaults = false,
    view = {
      ["<tab>"] = false,
      ["<s-tab>"] = false,
      ["gf"] = actions.goto_file,
      ["<C-w><C-f>"] = actions.goto_file_split,
      ["<C-w>gf"] = actions.goto_file_tab,
      ["<leader>e"] = actions.focus_files,
      ["<leader>b"] = actions.toggle_files,
    },
    file_panel = {
      ["j"] = actions.select_next_entry,
      ["<down>"] = actions.next_entry,
      ["k"] = actions.select_prev_entry,
      ["<up>"] = actions.prev_entry,
      ["<cr>"] = actions.select_entry,
      ["o"] = actions.select_entry,
      ["<2-LeftMouse>"] = actions.select_entry,
      ["-"] = actions.toggle_stage_entry,
      ["S"] = actions.stage_all,
      ["U"] = actions.unstage_all,
      ["X"] = actions.restore_entry,
      ["R"] = actions.refresh_files,
      ["L"] = actions.open_commit_log,
      ["<c-b>"] = actions.scroll_view(-0.25),
      ["<c-f>"] = actions.scroll_view(0.25),
      -- ["<tab>"] = actions.select_next_entry,
      -- ["<s-tab>"] = actions.select_prev_entry,
      ["<tab>"] = nil,
      ["<s-tab>"] = nil,
      ["gf"] = actions.goto_file,
      ["<C-w><C-f>"] = actions.goto_file_split,
      ["<C-w>gf"] = actions.goto_file_tab,
      ["i"] = actions.listing_style,
      ["f"] = actions.toggle_flatten_dirs,
      ["<leader>e"] = actions.focus_files,
      ["<leader>b"] = actions.toggle_files,
    },
    file_history_panel = {
      ["g!"] = actions.options,
      ["<C-A-d>"] = actions.open_in_diffview,
      ["y"] = actions.copy_hash,
      ["L"] = actions.open_commit_log,
      ["zR"] = actions.open_all_folds,
      ["zM"] = actions.close_all_folds,
      ["j"] = actions.next_entry,
      ["<down>"] = actions.next_entry,
      ["k"] = actions.prev_entry,
      ["<up>"] = actions.prev_entry,
      ["<cr>"] = actions.select_entry,
      ["o"] = actions.select_entry,
      ["<2-LeftMouse>"] = actions.select_entry,
      ["<c-b>"] = actions.scroll_view(-0.25),
      ["<c-f>"] = actions.scroll_view(0.25),
      -- ["<tab>"] = actions.select_next_entry,
      -- ["<s-tab>"] = actions.select_prev_entry,
      ["<tab>"] = false,
      ["<s-tab>"] = false,
      ["gf"] = actions.goto_file,
      ["<C-w><C-f>"] = actions.goto_file_split,
      ["<C-w>gf"] = actions.goto_file_tab,
      ["<leader>e"] = actions.focus_files,
      ["<leader>b"] = actions.toggle_files,
    },
    option_panel = {
      -- ["<tab>"] = actions.select_entry,
      ["<tab>"] = false,
      ["q"] = actions.close,
    },
  },
}
-- open file change list
vim.keymap.set("n", ",df", ":DiffviewOpen<CR>", { desc = "open diff view" })
vim.keymap.set("n", ",dh", ":DiffviewFileHistory<CR>", { desc = "file history " })
