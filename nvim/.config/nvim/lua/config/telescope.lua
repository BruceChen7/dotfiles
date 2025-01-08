local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
  vim.notify "telescope not found!"
  return
end

local actions = require "telescope.actions"

-- disable preview binaries
local previewers = require "telescope.previewers"
local Job = require "plenary.job"
local new_maker = function(filepath, bufnr, opts)
  filepath = vim.fn.expand(filepath)
  Job:new({
    command = "file",
    args = { "--mime-type", "-b", filepath },
    on_exit = function(j)
      local mime_type = vim.split(j:result()[1], "/")[1]
      if mime_type == "text" then
        previewers.buffer_previewer_maker(filepath, bufnr, opts)
      else
        -- maybe we want to write something to the buffer here
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "BINARY" })
        end)
      end
    end,
  }):sync()
end

telescope.setup {
  defaults = {
    buffer_previewer_maker = new_maker,
    prompt_prefix = " ",
    selection_caret = " ",
    path_display = {
      shorten = {
        -- e.g. for a path like
        --   `alpha/beta/gamma/delta.txt`
        -- setting `path_display.shorten = { len = 1, exclude = {1, -1} }`
        -- will give a path like:
        --   `alpha/b/g/delta.txt`
        len = 3,
        exclude = { 1, -1 },
      },
    },

    mappings = {
      i = {
        -- history command
        ["<C-n>"] = actions.cycle_history_next,
        ["<C-p>"] = actions.cycle_history_prev,

        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,

        ["<C-c>"] = actions.close,
        ["<esc>"] = actions.close,
        -- used to clear prompt
        ["<C-u>"] = false,

        ["<Down>"] = actions.move_selection_next,
        ["<Up>"] = actions.move_selection_previous,

        ["<CR>"] = actions.select_default,
        ["<C-x>"] = actions.select_horizontal,
        ["<C-v>"] = actions.select_vertical,
        ["<C-t>"] = actions.select_tab,

        ["<C-h>"] = actions.preview_scrolling_up,
        ["<C-l>"] = actions.preview_scrolling_down,

        ["<PageUp>"] = actions.results_scrolling_up,
        ["<PageDown>"] = actions.results_scrolling_down,

        ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
        ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
        ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
        ["<S-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
        -- ["<C-l>"] = actions.complete_tag,
        -- ["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
      },

      n = {
        ["<esc>"] = actions.close,
        ["<C-c>"] = actions.close,
        ["<CR>"] = actions.select_default,
        ["<C-x>"] = actions.select_horizontal,
        ["<C-v>"] = actions.select_vertical,
        ["t"] = actions.select_tab,

        ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
        ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
        ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
        ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

        ["j"] = actions.move_selection_next,
        ["k"] = actions.move_selection_previous,
        ["H"] = actions.move_to_top,
        ["M"] = actions.move_to_middle,
        ["L"] = actions.move_to_bottom,

        ["<Down>"] = actions.move_selection_next,
        ["<Up>"] = actions.move_selection_previous,
        ["gg"] = actions.move_to_top,
        ["G"] = actions.move_to_bottom,

        ["<C-u>"] = actions.preview_scrolling_up,
        ["<C-d>"] = actions.preview_scrolling_down,

        ["<PageUp>"] = actions.results_scrolling_up,
        ["<PageDown>"] = actions.results_scrolling_down,

        -- ["?"] = actions.which_key,
      },
    },
  },
  pickers = {
    find_files = {
      -- theme = "ivy",
      previewer = false,
      -- find_command = { "fd", "--hidden", "--type", "f" },
      find_command = { "fd", "--hidden", "--type", "f", "--exclude", ".git" },
    },
  },

  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },

    frecency = {
      auto_validate = true,
      ignore_patterns = { "*/.git", "*/.git/*", "*/.DS_Store", "*/term*" },
      -- https://github.com/nvim-telescope/telescope-frecency.nvim/issues/270
      db_safe_mode = false,

      -- …… other configs
    },
    zoxide = {
      prompt_title = "zoxide",
      mappings = {
        default = {
          after_action = function(selection)
            print("Update to (" .. selection.z_score .. ") " .. selection.path)
          end,
        },
        ["<C-s>"] = {
          before_action = function(selection)
            -- print "before C-s"
          end,
          action = function(selection)
            vim.cmd.edit(selection.path)
          end,
        },
        -- Opens the selected entry in a new split
      },
    },
  },
}
telescope.load_extension "fzf"
telescope.load_extension "undo"
telescope.load_extension "frecency"

vim.keymap.set("n", "g1", function()
  -- fetch current cursor word
  local current_word = vim.fn.expand "<cword>"
  require("telescope.builtin").grep_string { search = current_word }
end, { noremap = true, silent = true, desc = "find current word" })
vim.keymap.set("n", "<space>tg", ":Telescope live_grep<CR>", { desc = "Telescope live_grep" })
vim.keymap.set("n", "<c-p>", "<cmd>Telescope find_files<cr>", { desc = "Telescope find_files" })
vim.keymap.set("n", "<space>tr", ":Telescope resume<CR>", { desc = "Telescope resume" })
vim.keymap.set("n", "<m-m>", function()
  local util = require "utils"
  local root = util.find_root_dir()
  if root ~= vim.fn.getcwd() then
    util.change_to_current_buffer_root_dir()
  end
  vim.cmd "Telescope frecency workspace=CWD"
end, { desc = "Telescope frequency buffer" })

vim.keymap.set("n", "<m-b>", "<cmd>Telescope buffers<CR>", { noremap = true, silent = true, desc = "find buffers" })

vim.keymap.set("n", "<m-o>", function()
  vim.cmd "Telescope frecency"
end, { desc = "Telescope frequency buffer" })

local current_branch = function()
  local output = vim.fn.system "git symbolic-ref --short HEAD 2>/dev/null"
  local branch = output:gsub("%s+$", "")
  return branch
end

local get_branches = function()
  local current = current_branch()

  local job = require("plenary.job"):new {
    command = "git",
    args = { "for-each-ref", "--format=%(refname:short)" },
  }

  job:sync()
  local result = job:result()

  local branches = {}
  for _, v in pairs(result) do
    if v ~= current then
      table.insert(branches, v)
    end
  end

  return branches
end

local diff_files_to = function(branch)
  local branches = get_branches()

  if not vim.tbl_contains(branches, branch) then
    if vim.tbl_contains(branches, "master") then
      branch = "master"
    elseif vim.tbl_contains(branches, "main") then
      branch = "main"
    else
      return
    end
  end

  require("telescope.builtin").find_files {
    prompt_title = "Changed from <" .. branch .. ">",
    find_command = { "git", "diff", "--diff-filter=d", "--name-only", branch },
    previewer = true,
  }
end

vim.api.nvim_create_user_command("DiffFilesTo", function(args)
  diff_files_to(args.args)
end, { nargs = 1 })

vim.keymap.set("n", "\\rr", function()
  diff_files_to "release"
end, { desc = "Diff files to release" })
