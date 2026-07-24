--- Coordinate conversion between Neovim and pi.
---
--- Neovim uses 0-indexed byte positions for cursor columns.
--- pi    uses 0-indexed UTF-16 code-unit positions for cursor columns.
---
--- For ASCII text the two are identical. CJK characters are 3 bytes in
--- UTF-8 but only 1 code-unit in UTF-16, so conversion is required.
---
--- Requires Neovim ≥ 0.11 for vim.str_utfindex / vim.str_byteindex.

local M = {}

--- Convert a Neovim byte column (0-indexed) to a pi UTF-16 code-unit column (0-indexed).
--- @param line string  The buffer line text
--- @param byte_col integer  0-indexed byte offset
--- @return integer  0-indexed UTF-16 code-unit offset
function M.byte_to_utf16(line, byte_col)
  -- vim.str_utfindex returns (utf8_index, utf16_index) at a given byte offset
  -- The second return value is the UTF-16 code-unit index (0-indexed)
  local _, utf16_col = vim.str_utfindex(line or "", byte_col or 0)
  return utf16_col
end

--- Convert a pi UTF-16 code-unit column (0-indexed) to a Neovim byte column (0-indexed).
--- @param line string  The buffer line text
--- @param utf16_col integer  0-indexed UTF-16 code-unit offset
--- @return integer  0-indexed byte offset
function M.utf16_to_byte(line, utf16_col)
  return vim.str_byteindex(line or "", utf16_col or 0)
end

return M
