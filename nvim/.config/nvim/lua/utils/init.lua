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

M.treesitter = {}

--- Find the node at a specific position in a tree
-- @param node The root node to search from
-- @param line The line position (0-based)
-- @param col The column position (0-based)
-- @return The node at the position, or nil if not found
M.treesitter.find_node_at_pos = function(node, line, col)
  if not node then
    return nil
  end

  -- Check if cursor is within this node's range
  local start_line, start_col, end_line, end_col = node:range()
  if
    line < start_line
    or line > end_line
    or (line == start_line and col < start_col)
    or (line == end_line and col >= end_col)
  then
    return nil
  end

  -- Check if this node contains the cursor position
  if node:child_count() > 0 then
    -- Check children first
    for child in node:iter_children() do
      local child_result = M.treesitter.find_node_at_pos(child, line, col)
      if child_result then
        return child_result
      end
    end
  end

  return node
end

--- Get the current buffer's treesitter parser and root node
-- @return A table with parser and root node, or nil if not available
M.treesitter.get_current_context = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local lang_tree = vim.treesitter.get_parser(bufnr):parse()[1]
  if not lang_tree then
    return nil
  end

  local root = lang_tree:root()
  if not root then
    return nil
  end

  return {
    parser = lang_tree,
    root = root,
  }
end

--- Get cursor position in treesitter coordinates (0-based)
-- @return A table with line and col (0-based)
M.treesitter.get_cursor_pos = function()
  local cursor_line, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  return {
    line = cursor_line - 1, -- Convert to 0-based
    col = cursor_col, -- Already 0-based
  }
end

--- Get the treesitter node at the current cursor position
-- @return The node at cursor position, or nil if not available
M.treesitter.get_node_at_cursor = function()
  local context = M.treesitter.get_current_context()
  if not context then
    return nil
  end

  local cursor_pos = M.treesitter.get_cursor_pos()
  return M.treesitter.find_node_at_pos(context.root, cursor_pos.line, cursor_pos.col)
end

M.get_go_nearest_function = function()
  local node = M.treesitter.get_node_at_cursor()
  if not node then
    return nil
  end

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

M.register_keymaps = function(keymaps)
  for _, keymap in ipairs(keymaps) do
    vim.keymap.set(keymap.mode or "n", keymap[1], keymap[2], {
      desc = keymap.desc,
      noremap = true,
      nowait = keymap.nowait,
    })
  end
end

return M
