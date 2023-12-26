local M = {}

M.remove_leading_char = function(str, char)
  local result = str:gsub("^" .. char .. "+", "")
  return result
end

M.find_root_dir = function()
  local buf_name = vim.api.nvim_buf_get_name(0)
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
  return buf_name:find "mms" or buf_name:find "video"
end

return M
