local mark = require "harpoon.mark"
local ui = require "harpoon.ui"
local term = require "harpoon.term"

vim.keymap.set("n", ",ha", function()
  mark.add_file()
end, { desc = "add harpoon bookmark" })
-- next marks
vim.keymap.set("n", ",hn", function()
  ui.nav_next()
end, { desc = "nav next bookmark" })
--prev marks
vim.keymap.set("n", ",hp", function()
  ui.nav_prev()
end, { desc = "nav prev bookmark" })

vim.keymap.set("n", ",ht", function()
  ui.toggle_quick_menu()
end, { desc = "toggle quick menu" })

vim.keymap.set("n", "m2", function()
  term.gotoTerminal(1)
end, { desc = "goto terminal" })

local ts_utils = require "nvim-treesitter.ts_utils"
local function get_nearest_function()
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

local function get_go_test_command()
  -- 获取当前buffer的绝对路径
  local buf_name = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local function_name = get_nearest_function()
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

  local is_mac = function()
    return vim.loop.os_uname().sysname:find "Darwin"
  end
  local export_cmd = ""
  if is_mac() then
    export_cmd = "export env=test && export cid=sg  && gvm use go1.14 "
  end
  if export_cmd == "" then
    return " cd " .. dir .. " && go test -gcflags=all=-l -run " .. function_name
  else
    local cmd = export_cmd .. " && cd " .. dir .. " && go test -gcflags=all=-l -run " .. function_name
    return cmd
  end
end
-- use go test
vim.keymap.set("n", "m3", function()
  local cmd = get_go_test_command()
  if cmd == nil then
    return
  end
  term.sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "open go test in terminal" })

local find_root_dir = function()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local lspconfig_util = require "lspconfig.util"
  return lspconfig_util.root_pattern("go.mod", ".git")(buf_name)
end

vim.keymap.set("n", "m4", function()
  term.sendCommand(1, "yazi")
  require("harpoon.term").gotoTerminal(1)
  vim.api.nvim_feedkeys("i", "n", false)
end, { desc = "open yazi in terminal" })

vim.keymap.set("n", "<leader>tf", function()
  local cmd = "git log -p " .. vim.fn.expand "%:p"
  require("harpoon.term").sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "open git log for this file in terminal" })

vim.keymap.set("n", "<leader>tg", function()
  local root = find_root_dir()
  if not root then
    root = vim.fn.getcwd()
  end
  local cmd = "tig -C " .. root
  require("harpoon.term").sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
end, { desc = "open tig" })

vim.keymap.set("n", "m5", function()
  local cmd = "git diff master -- " .. find_root_dir()
  term.sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
  vim.api.nvim_feedkeys("i", "n", false)
end, { desc = "open git diff in terminal" })

local term = require "harpoon.term"
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
    -- 使用系统命令查看yazi进程是否存在
    local cmd = "ps -ef | grep yazi | grep -v grep | awk '{print $2}'"
    local yazi_pid = vim.fn.system(cmd)
    if yazi_pid ~= "" then
      -- kill it
      -- vim.fn.system("kill -9 " .. yazi_pid)
    end
    vim.notify_once "kill yazi"
    vim.cmd "startinsert"
    if yazi_pid ~= "" then
      -- 输入q
      vim.api.nvim_feedkeys("q", "n", false)
    end
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

require("harpoon").setup {
  global_settings = {
    enter_on_sendcmd = true,
  },
}
