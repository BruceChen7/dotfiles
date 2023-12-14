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

M.relative_path = function()
  -- call shell command realpath
  local cmd = string.format("realpath --relative-to='%s' '%s'", src, dest)
  local result = vim.fn.system(cmd)
  return string.gsub(result, "\n", "")
end

M.is_mac = function()
  return vim.loop.os_uname().sysname:find "Darwin"
end

return M
