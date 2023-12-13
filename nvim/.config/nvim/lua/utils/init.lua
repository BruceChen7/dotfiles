local M = {}

M.remove_leading_char = function(str, char)
  local result = str:gsub("^" .. char .. "+", "")
  return result
end

return M
