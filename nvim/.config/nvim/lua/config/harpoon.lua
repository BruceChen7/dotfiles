local mark = require "harpoon.mark"
local ui = require "harpoon.ui"
local term = require "harpoon.term"

vim.keymap.set("n", "<space>ha", function()
  mark.add_file()
end, { desc = "add harpoon bookmark" })
-- next marks
vim.keymap.set("n", "<space>hn", function()
  ui.nav_next()
end, { desc = "nav next bookmark" })
--prev marks
vim.keymap.set("n", "<space>hp", function()
  ui.nav_prev()
end, { desc = "nav prev bookmark" })

vim.keymap.set("n", "\\hf", function()
  ui.toggle_quick_menu()
end, { desc = "toggle quick menu" })

vim.keymap.set("n", "m2", function()
  term.gotoTerminal(1)
end, { desc = "goto terminal" })

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
    vim.notify("root is " .. root)
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
    return " cd "
      .. dir
      .. " && go test -tags='integration_test,unit_test' -tags=unit_test -gcflags=all=-l -run "
      .. function_name
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
vim.keymap.set("n", "m3", function()
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
  term.sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "open go test in terminal" })

vim.keymap.set("n", "<leader>tl", function()
  local cmd = 'git log -p "' .. vim.fn.expand "%:p" .. '"'
  require("harpoon.term").sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "open git log for this file in terminal" })

vim.keymap.set("n", "<leader>tbb", function()
  local current_file_path_with_name = vim.fn.expand "%:p"
  local cmd = "tig blame " .. current_file_path_with_name
  require("harpoon.term").sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "tig blame current file in terminal" })

vim.keymap.set("n", "<leader>tt", function()
  local utils = require "utils"
  local root = utils.find_root_dir()
  if not root then
    root = vim.fn.getcwd()
  end
  local cmd = 'tig -C "' .. root .. '"'
  require("harpoon.term").sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "open tig" })

vim.keymap.set("n", "m5", function()
  local utils = require "utils"
  local cmd = "git diff master -- " .. utils.find_root_dir()
  term.sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
  -- vim.api.nvim_feedkeys("i", "n", false)
end, { desc = "open git diff in terminal" })

local saved_buffer = nil
local last_term_idx = nil
local function gotoTerminal(tid, save_buf)
  saved_buffer = save_buf and vim.fn.bufnr "%" or saved_buffer
  term.gotoTerminal(tid)
  last_term_idx = tid
  vim.api.nvim_command "startinsert"
end

local function isInTerminal()
  local current_buffer_name = vim.fn.bufname "%"
  return string.match(current_buffer_name, "^term")
end

local function toggleTerminal(open, other)
  if saved_buffer == nil then
    gotoTerminal(open, true)
  else
    if isInTerminal() then
      if last_term_idx == other then
        gotoTerminal(open)
      else
        vim.cmd("buffer " .. saved_buffer)
      end
    else
      gotoTerminal(open, true)
    end
  end
end

-- https://www.reddit.com/r/neovim/comments/16b0n3a/whats_your_new_favorite_functions_share_em/
vim.keymap.set({ "n", "t" }, "<C-0>", function()
  toggleTerminal(1, 2)
end, { desc = "open 0 toggle terminal" })
vim.keymap.set({ "n", "t" }, "<C-9>", function()
  toggleTerminal(2, 1)
end, { desc = "open 9 toggle terminal" })

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

function set_terminal_keymaps()
  local opts = { noremap = true }
  -- using <esc> to enter normal mode
  vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd "autocmd! TermOpen term://* lua set_terminal_keymaps()"

require("harpoon").setup {
  global_settings = {
    enter_on_sendcmd = true,
  },
}
