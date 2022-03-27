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
  vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
  -- vim.api.nvim_buf_set_keymap(0, 't', 'jk', [[<C-\><C-n>]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<tab>h", [[<C-\><C-n><C-W>h]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<tab>j", [[<C-\><C-n><C-W>j]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<tab>k", [[<C-\><C-n><C-W>k]], opts)
  vim.api.nvim_buf_set_keymap(0, "t", "<tab>l", [[<C-\><C-n><C-W>l]], opts)
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd "autocmd! TermOpen term://* lua set_terminal_keymaps()"

local Terminal = require("toggleterm.terminal").Terminal

local lspconfig_util = require "lspconfig.util"
local find_root = lspconfig_util.root_pattern ".git"

function _Tig_TOGGLE()
  local root = find_root(vim.fn.expand "%:p")
  if not root then
    return
  end
  local tig = Terminal:new { cmd = "tig -C " .. root, hidden = true }
  tig:toggle()
end

-- https://devhints.io/tig
function _Tig_Blame()
  local root = find_root(vim.fn.expand "%:p")
  if not root then
    return
  end
  file_name = vim.fn.expand "%:p"
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

function _Git_Diff_test()
  local branch = vim.fn.system {
    "git",
    "rev-parse",
    "--abbrev-ref",
    "HEAD",
  }
  -- TODO: when not have test branch do not diff
  require("toggleterm").exec("git diff test.." .. branch)
end

local u = require "util"
u.map("n", "<leader>tg", ":lua _Tig_TOGGLE()<CR>")
u.map("n", "<leader>tb", ":lua _Tig_Blame()<CR>")
u.map("n", "<leader>gs", ":lua  _Git_Status()<CR>")
u.map("n", "<leader>gdd", ":lua  _Git_Diff_Name_Only()<CR>")
u.map("n", "<leader>gdn", ":lua  _Git_Diff()<CR>")
u.map("n", "<leader>gdt", ":lua  _Git_Diff_Test()<CR>")
