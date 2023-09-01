local mark = require "harpoon.mark"
local ui = require "harpoon.ui"
local term = require "harpoon.term"
require("harpoon").setup {
  enter_on_sendcmd = true,
}

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
    print(node:type())
    node = node:parent()
  end
  print(node:type())
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
  -- 获取当前buffer的
end
-- use go test
vim.keymap.set("n", "m3", function()
  term.sendCommand(1, "go test -run " .. get_nearest_function())
end)
