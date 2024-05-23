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
  print("res is ", res, "cmd is ", cmd)
  return string.gsub(res, "\n", "")
end

M.is_mac = function()
  return vim.loop.os_uname().sysname:find "Darwin"
end

M.is_in_working_dir = function()
  local buf_name = vim.api.nvim_buf_get_name(0)
  -- buf_name contains `mms` or `video` string
  return buf_name:find "video"
end

-- https://shaneworld.github.io/p/neovim-%E4%BD%BF%E7%94%A8-lua-%E8%8E%B7%E5%8F%96-visual-mode-%E4%B8%8B%E9%80%89%E4%B8%AD%E7%9A%84%E6%96%87%E6%9C%AC/
M.get_visual_selection = function()
  local vstart = vim.fn.getpos "v"
  local vend = vim.fn.getcurpos()
  local lines = vim.api.nvim_buf_get_lines(0, vstart[2] - 1, vend[2], false)
  return table.concat(lines)
end

M.is_terminal_buffer = function()
  local bufname = vim.fn.bufname "%"
  return string.find(bufname, "^term://") ~= nil
end
return M
