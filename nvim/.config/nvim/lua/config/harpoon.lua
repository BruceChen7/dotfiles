local mark = require "harpoon.mark"
local ui = require "harpoon.ui"
local term = require "harpoon.term"

vim.keymap.set("n", "m1", function()
  mark.add_file()
end)
-- next marks
vim.keymap.set("n", ",hn", function()
  ui.nav_next()
end)
--prev marks
vim.keymap.set("n", ",hp", function()
  ui.nav_prev()
end, { desc = "nav prev bookmark" })

vim.keymap.set("n", ",hf", function()
  ui.toggle_quick_menu()
end)

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
    export_cmd = "export env=test && export cid=sg "
  end
  if export_cmd == "" then
    return " cd " .. dir .. " && go test -run " .. function_name
  else
    local cmd = export_cmd .. " && cd " .. dir .. " && go test -run " .. function_name
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

vim.keymap.set("n", "m5", function()
  local cmd = "git diff master -- " .. find_root_dir()
  term.sendCommand(1, cmd)
  require("harpoon.term").gotoTerminal(1)
  vim.api.nvim_feedkeys("i", "n", false)
end, { desc = "open git diff in terminal" })

require("harpoon").setup {
  global_settings = {
    enter_on_sendcmd = true,
  },
}
