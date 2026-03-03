-- Check if we are in diff mode
local function is_diff_mode()
  return vim.opt.diff:get() == true
end

local function get_winbar_path()
  local full_path = vim.fn.expand "%:p"
  return full_path:gsub(vim.fn.expand "$HOME", "~")
end

local function get_buffer_count()
  local buffers = vim.fn.execute "ls"
  local count = 0
  -- Match only lines that represent buffers, typically starting with a number followed by a space
  for line in string.gmatch(buffers, "[^\r\n]+") do
    if string.match(line, "^%s*%d+") then
      count = count + 1
    end
  end
  return count
end

-- Get diff file path for a specific window
local function get_diff_file_path_for_win(win_id)
  -- Use vim.api.nvim_win_get_buf for compatibility
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  if bufnr and bufnr > 0 then
    local bufname = vim.fn.bufname(bufnr)
    if bufname and bufname ~= "" then
      return bufname:gsub(vim.fn.expand "$HOME", "~")
    end
  end
  return "[No Name]"
end

-- Update winbar for all windows
local function update_all_windows()
  -- In diff mode, set winbar for each window
  if is_diff_mode() then
    for _, win_id in ipairs(vim.api.nvim_list_wins()) do
      local diff_path = get_diff_file_path_for_win(win_id)
      vim.wo[win_id].winbar = "%#WinBar1#diff %#WinBar2#" .. diff_path .. "%*"
    end
    return
  end

  -- Normal mode: use global winbar
  local home_replaced = get_winbar_path()
  local buffer_count = get_buffer_count()
  vim.opt.winbar = "%#WinBar1#%m "
    .. "%#WinBar2#("
    .. buffer_count
    .. ") "
    .. "%#WinBar1#"
    .. home_replaced
    .. "%*%=%#WinBar2#"
end

-- Function to update the winbar
local function update_winbar()
  update_all_windows()
end

-- Autocmd to update the winbar on BufEnter and WinEnter events
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "OptionSet" }, {
  pattern = "diff",
  callback = update_all_windows,
})

-- Also trigger on BufEnter/WinEnter to check diff mode
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  callback = update_all_windows,
})

-- This code is in your nvim/.config/nvim/after/plugin/winbar.lua file and is doing a few things:
--  1 It creates an autocmd that triggers on VimEnter (when Vim starts up)
--  2 When triggered, it:
--     • Sets tabline option to empty string (""), which hides the tab bar
--     • Sets showtabline option to 0, which means "never show the tab bar"
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.opt.tabline = ""
    vim.opt.showtabline = 0
  end,
  once = true,
})
