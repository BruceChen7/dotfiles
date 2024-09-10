function _G.set_terminal_keymaps()
  local opts = { buffer = 0 }
  -- using <esc> to enter normal mode
  -- vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
  -- vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
  -- vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
  -- vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
  -- vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  -- vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
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

local ts_utils = require "nvim-treesitter.ts_utils"
local function get_go_nearest_function()
  local node = ts_utils.get_node_at_cursor()
  -- 获取父parent node
  while node and node:type() ~= "function_declaration" do
    -- print(node:type())
    node = node:parent()
  end
  if node and node:type() == "function_declaration" then
    -- local text = vim.treesitter.get_node_text(node, 0)
    local child = node:child(0)
    local child_count = node:child_count()
    -- 遍历child_count次
    for i = 0, child_count - 1 do
      child = node:child(i)
      if child:type() == "identifier" then
        return vim.treesitter.get_node_text(child, 0)
      end
    end
  end
end

local function get_zig_test_declaration()
  local node = ts_utils.get_node_at_cursor()
  -- 获取父parent node
  while node and node:type() ~= "TestDecl" do
    -- print(node:type())
    node = node:parent()
  end
  if node and node:type() == "TestDecl" then
    return true
  else
    return false
  end
end

local function get_test_command()
  -- 让vim 重新刷新当前buffer
  vim.api.nvim_command "redraw"
  -- 获取当前buffer的文件类型
  local buf_name = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local filetype = vim.bo.filetype

  -- 如果是zig, 命令是zig build
  if filetype == "zig" then
    if get_zig_test_declaration() then
      return "cd  " .. dir .. " && zig test " .. buf_name
    end
  end

  if filetype == "python" then
    -- 获取当前buffer所在的目录
    return "cd " .. dir .. " && python3 -m unittest discover -s ./"
  end

  if filetype ~= "go" then
    return
  end
  -- 获取当前buffer的绝对路径
  local function_name = get_go_nearest_function()
  -- function name whether start with Test
  if not function_name then
    -- message notice
    vim.notify "no function found"
    return
  end
  if string.sub(function_name, 1, 4) ~= "Test" then
    vim.notify "Test function not found"
    return
  end

  if function_name == nil then
    vim.notify "no function found"
    return
  end
  local utils = require "utils"
  local export_cmd = ""
  if utils.is_mac() then
    local root = utils.find_root_dir()
    -- vim.notify("root is " .. root)
    local last_part = string.match(root, "([^/]+)$")
    local project_name = "luckyvideo"
    if last_part == "ecommerce" then
      project_name = "core"
    else
      project_name = "luckyvideo"
    end

    if utils.is_in_working_dir() then
      export_cmd = "export env=test && export cid=global && export PROJECT_NAME="
        .. project_name
        .. " && export MODULE_NAME="
        .. last_part
        .. " && export SP_UNIX_SOCKET=/tmp/spex.sock"
    end
  end
  if export_cmd == "" then
    return " cd " .. dir .. " && go test -tags='integration_test,unit_test'  -gcflags=all=-l -run " .. function_name
  else
    local cmd = export_cmd
      .. " && cd "
      .. dir
      .. " && go test -tags='integration_test,unit_test' -gcflags=all=-l -run "
      .. function_name
    return cmd
  end
end
-- use go test
vim.keymap.set("n", "<F2>", function()
  local cmd = get_test_command()
  if cmd == nil then
    return
  end
  local utils = require "utils"
  if utils.is_mac() then
    local spex_cmd =
      "inp-client --mode=forward --local_network=unix --local_address=/tmp/spex.sock --remote_network=unix --remote_address=/run/spex/spex.sock"
    vim.fn.jobstart(spex_cmd, {
      on_stdout = function(_, data) end,
    })
  end
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open go test in terminal" })

vim.keymap.set("n", "<leader>tl", function()
  local cmd = 'git log -p "' .. vim.fn.expand "%:p" .. '"'
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open git log for this file in terminal" })

vim.keymap.set("n", "\\tb", function()
  local current_file_path_with_name = vim.fn.expand "%:p"
  local cmd = "tig blame " .. current_file_path_with_name
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "tig blame current file in terminal" })

vim.keymap.set("n", "<leader>tt", function()
  local utils = require "utils"
  local root = utils.find_root_dir()
  if not root then
    root = vim.fn.getcwd()
  end
  local cmd = 'tig -C "' .. root .. '"'
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open tig" })

vim.keymap.set("n", "\\gm", function()
  local utils = require "utils"
  local cmd = "git diff master -- " .. utils.find_root_dir()
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open git diff in terminal" })

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd "autocmd! TermOpen term://* lua set_terminal_keymaps()"

-- Define a shortcut key to diff the current buffer with the release branch differences and display them in the terminal
vim.keymap.set("n", "\\fh", function()
  local utils = require "utils"
  local root = utils.find_root_dir()
  -- local cmd = "git diff release -- " .. root
  -- diff the current file with the release branch
  local cmd = "git diff release -- " .. vim.fn.expand "%:p"
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "file differences b" })

vim.keymap.set({ "n", "t" }, "<c-0>", function()
  local utils = require "utils"
  local root_dir = utils.find_root_dir()
  if root_dir ~= nil then
    vim.cmd("1ToggleTerm dir=" .. root_dir)
    return
  end
  vim.cmd "1ToggleTerm "
end, { desc = "open terminal 1" })

vim.keymap.set({ "n", "t" }, "<c-9>", function()
  local utils = require "utils"
  local root_dir = utils.find_root_dir()
  if root ~= nil then
    vim.cmd("2ToggleTerm dir=" .. root_dir)
    return
  end
  vim.cmd "2ToggleTerm"
end, { desc = "open terminal 2" })

-- 记录终端缓冲区的编号
local terminal_buffer_nr = nil
-- 定义一个函数来处理终端的打开和跳转
local function toggle_terminal()
  if terminal_buffer_nr and vim.api.nvim_buf_is_valid(terminal_buffer_nr) then
    -- 如果终端缓冲区存在且有效，跳转到该缓冲区
    vim.cmd("buffer " .. terminal_buffer_nr)
  else
    -- 如果终端缓冲区不存在，创建一个新的终端缓冲区
    vim.cmd "enew" -- 创建一个新缓冲区
    vim.cmd "terminal" -- 在新缓冲区中打开终端
    terminal_buffer_nr = vim.api.nvim_get_current_buf() -- 记录当前终端缓冲区的编号
    print("new terminal " .. terminal_buffer_nr)
  end
end

vim.keymap.set({ "n", "t" }, "<c-8>", function()
  toggle_terminal()
end, { desc = "toggle fullscreen terminal" })
-- 设置快捷键
-- vim.keymap.set({ "n", "t" }, "<c-8>", toggle_terminal, { desc = "toggle fullscreen terminal" })

-- vim.keymap.set({ "n", "t" }, "<c-8>", function()
--   vim.cmd "enew" -- Create a new buffer
--   vim.cmd "terminal" -- Open a terminal buffer in the new buffer
-- end, { desc = "open fullscreen terminal" })

require("toggleterm").setup {
  --  -- size can be a number or function which is passed the current terminal
  size = function(term)
    if term.direction == "horizontal" then
      return 10
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  on_open = function(term)
    vim.cmd "startinsert!"
    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
  end,
  open_mapping = [[<m-=>]],
  shade_terminals = true,
  insert_mappings = true, -- whether or not the open mapping applies in insert mode
  -- direction = "horizontal",
  direction = "horizontal",
  close_on_exit = true, -- close the terminal window when the process exits
  start_in_insert = true,
}

-- https://github.com/theopn/theovim/blob/main/lua/core.lua#L155
-- {{{ Terminal autocmd
-- Switch to insert mode when terminal is open
local term_augroup = vim.api.nvim_create_augroup("Terminal", { clear = true })
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
  -- TermOpen: for when terminal is opened for the first time
  -- BufEnter: when you navigate to an existing terminal buffer
  group = term_augroup,
  pattern = "term://*", --> only applicable for "BufEnter", an ignored Lua table key when evaluating TermOpen
  callback = function()
    -- insert
    vim.cmd "startinsert"
  end,
})
-- Automatically close terminal unless exit code isn't 0
vim.api.nvim_create_autocmd("TermClose", {
  group = term_augroup,
  callback = function()
    if vim.v.event.status == 0 then
      vim.api.nvim_buf_delete(0, {})
      vim.notify_once "Previous terminal job was successful!"
    else
      vim.notify_once "Error code detected in the current terminal job!"
    end
  end,
})
