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
end)

vim.keymap.set("n", ",hf", function()
  ui.toggle_quick_menu()
end)

vim.keymap.set("n", "m2", function()
  term.gotoTerminal(1)
end)

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
  local cmd = "cd " .. dir .. " && go test -run " .. get_nearest_function()
  return cmd
end
-- use go test
vim.keymap.set("n", "m3", function()
  term.sendCommand(1, get_go_test_command())
  require("harpoon.term").gotoTerminal(1)
end)

require("harpoon").setup {
  global_settings = {
    enter_on_sendcmd = true,
  },
}
