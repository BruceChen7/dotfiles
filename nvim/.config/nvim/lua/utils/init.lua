local M = {}

M.remove_leading_char = function(str, char)
  local result = str:gsub("^" .. char .. "+", "")
  return result
end

M.find_root_dir = function()
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or buf_name == nil then
    -- return current working dir with full path
    return vim.fn.getcwd()
  end

  local lspconfig_util = require "lspconfig.util"
  return lspconfig_util.root_pattern(".obsidian", ".git", "go.mod")(buf_name)
end

M.relative_path = function(src, link_to_file_path)
  -- call shell command realpath
  -- if not M:is_mac() then
  --   local cmd = string.format("realpath --relative-to='%s' '%s'", link_to_file_path, src)
  --   local result = vim.fn.system(cmd)
  --   return string.gsub(result, "\n", "")
  -- end
  local cmd = "python3 -c \"import os.path; print(os.path.relpath('" .. link_to_file_path .. "', '" .. src .. "'))\""
  local res = vim.fn.system(cmd)
  -- print("res is ", res, "cmd is ", cmd)
  return string.gsub(res, "\n", "")
end

M.is_mac = function()
  return vim.loop.os_uname().sysname:find "Darwin"
end

M.is_m1_mac = function()
  if not M.is_mac() then
    return false
  end
  return vim.loop.os_uname().machine:find "arm64" ~= nil
end

M.is_in_working_dir = function()
  local buf_name = vim.api.nvim_buf_get_name(0)
  -- buf_name contains `mms` or `video` string
  return buf_name:find "work"
end

M.change_to_current_buffer_root_dir = function()
  local root = M.find_root_dir()
  if not root then
    vim.notify "no root dir"
    return
  end
  vim.cmd.tcd(root)
end

-- https://shaneworld.github.io/p/neovim-%E4%BD%BF%E7%94%A8-lua-%E8%8E%B7%E5%8F%96-visual-mode-%E4%B8%8B%E9%80%89%E4%B8%AD%E7%9A%84%E6%96%87%E6%9C%AC/
M.get_visual_selection = function()
  local vstart = vim.fn.getpos "v"
  local vend = vim.fn.getcurpos()
  local lines = vim.api.nvim_buf_get_lines(0, vstart[2] - 1, vend[2], false)
  return table.concat(lines)
end

M.find_all_visible_buffers = function()
  local buffers = vim.api.nvim_list_bufs()
  local visible_buffers = {}

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, "buflisted") then
      table.insert(visible_buffers, buf)
    end
  end
  return visible_buffers
end

--
M.is_terminal_buffer = function()
  local bufname = vim.fn.bufname "%"
  return string.find(bufname, "^term://") ~= nil
end

M.get_go_nearest_function = function()
  local ts_utils = require "nvim-treesitter.ts_utils"
  -- Get the current node at cursor position
  local node = ts_utils.get_node_at_cursor()

  -- Traverse up the node tree to find the nearest function declaration
  while node and node:type() ~= "function_declaration" do
    node = node:parent() -- Move to parent node
  end

  -- Check if we found a valid function declaration
  if node and node:type() == "function_declaration" then
    -- Get first child node
    local child = node:child(0)
    local child_count = node:child_count() -- Get total number of children

    -- Iterate through all child nodes
    for i = 0, child_count - 1 do
      child = node:child(i) -- Get current child node

      -- Check if child is an identifier (function name)
      if child:type() == "identifier" then
        -- Return the function name text
        return vim.treesitter.get_node_text(child, 0)
      end
    end
  end

  -- If no function name found, return nil
  return nil
end

return M
