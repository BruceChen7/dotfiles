require("toggleterm").setup {
  --  -- size can be a number or function which is passed the current terminal
  size = function(term)
    if term.direction == "horizontal" then
      return 30
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  open_mapping = [[<m-=>]],
  --  hide_numbers = true, -- hide the number column in toggleterm buffers
  --  shade_filetypes = {},
  shade_terminals = true,
  insert_mappings = true, -- whether or not the open mapping applies in insert mode
  --  persist_size = true,
  -- direction = 'vertical',
  direction = "float",
  close_on_exit = true, -- close the terminal window when the process exits
}

function _G.set_terminal_keymaps()
  local opts = { noremap = true }
  -- using <esc> to enter normal mode
  vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
  -- vim.api.nvim_buf_set_keymap(0, 't', 'jk', [[<C-\><C-n>]], opts)
  -- vim.api.nvim_buf_set_keymap(0, "t", "<tab>h", [[<C-\><C-n><C-W>h]], opts)
  -- vim.api.nvim_buf_set_keymap(0, "t", "<tab>j", [[<C-\><C-n><C-W>j]], opts)
  -- vim.api.nvim_buf_set_keymap(0, "t", "<tab>k", [[<C-\><C-n><C-W>k]], opts)
  -- vim.api.nvim_buf_set_keymap(0, "t", "<tab>l", [[<C-\><C-n><C-W>l]], opts)
end

local Terminal = require("toggleterm.terminal").Terminal

local lspconfig_util = require "lspconfig.util"
local find_root = lspconfig_util.root_pattern ".git"

local function _Tig_TOGGLE()
  local root = find_root(vim.fn.expand "%:p")
  if not root then
    -- FIXME(ming.chen): use vim.notify()
    -- vim.notify("use working directory instead", vim.log.levels.INFO)
    root = vim.fn.getcwd()
  end
  local tig = Terminal:new { cmd = "tig -C " .. root, hidden = true }
  tig:toggle()
end

-- https://devhints.io/tig
local function _Tig_Blame()
  local root = find_root(vim.fn.expand "%:p")
  if not root then
    root = vim.fn.getcwd()
    vim.notify "use working directory instead"
  end
  local file_name = vim.fn.expand "%:p"
  if not file_name then
    return
  end
  local tig_name_file_blame = Terminal:new { cmd = "tig -C " .. root .. " " .. file_name }
  tig_name_file_blame:toggle()
end

function _Git_Status()
  require("toggleterm").exec("git status", 1, 12)
end

function _Git_Diff_Name_Only()
  require("toggleterm").exec("git diff --name-only", 1, 12)
end

function _Git_Diff()
  require("toggleterm").exec("git diff ", 1, 12)
end

function _Git_file_diff()
  require("toggleterm").exec("git log -p " .. vim.fn.expand "%:p", 1, 12)
end

function _Git_Diff_test()
  local branch = vim.fn.system {
    "git",
    "rev-parse",
    "--abbrev-ref",
    "HEAD",
  }

  -- TODO(ming.chen): get current branch name
  allBrach = vim.fn.system {
    "git",
    "branch",
    "-a",
  }
  require("toggleterm").exec("git diff test.." .. branch)
end

function _GitUi()
  local root = find_root(vim.fn.expand "%:p")
  if not root then
    -- FIXME(ming.chen): use vim.notify()
    -- vim.notify("use working directory instead", vim.log.levels.INFO)
    root = vim.fn.getcwd()
  end
  local tig = Terminal:new { cmd = "gitui -d " .. root, hidden = true }
  tig:toggle()
end
local u = require "util"
-- vim.keymap.set("n", "<leader>tg", ":lua _Tig_TOGGLE()<CR>")
vim.keymap.set("n", "<leader>tbf", function()
  _Tig_Blame()
end, { desc = "get file history in git commit" })
-- u.map("n", "<leader>tf", ":lua _Git_file_diff()<CR>")
u.map("n", "<leader>gs", ":lua  _Git_Status()<CR>")
u.map("n", "<leader>gdd", ":lua  _Git_Diff_Name_Only()<CR>")
u.map("n", "<leader>gdn", ":lua  _Git_Diff()<CR>")
