local u = require "util"
-- https://github.com/Allaman/nvim/blob/main/lua/mappings.lua
local default_options = { noremap = true, silent = true }

-- ============================================================================
-- Configuration
-- ============================================================================
local config = {
  -- Paths
  diary_base_path = "~/work/notes/Calendar/Daily Notes/",
  nvim_config_path = "~/.config/nvim/",

  -- Window sizing
  resize_vertical_step = 5,
  resize_horizontal_step = 3,
  quickfix_height = 20,
  asyncrun_height = 10,

  -- Buffer management
  persist_terminal_buffers = true,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Markdown Utilities
local function trim_markdown_header(text)
  text = vim.trim(text)
  if not text:match "^#+" then
    return nil, "Text must start with #"
  end
  -- Remove leading # symbols and whitespace
  local header = text:gsub("^#+%s*", "")
  return header, nil
end

local function parse_markdown_link(content)
  local start_idx = content:find "%("
  local end_idx = content:find "%)"
  if not start_idx or not end_idx then
    return nil, "Invalid markdown link format"
  end

  local link = content:sub(start_idx + 1, end_idx - 1)
  local hash_idx = link:find "#"
  if not hash_idx then
    return nil, "Link must contain # anchor"
  end

  return {
    file_path = link:sub(1, hash_idx - 1),
    header = link:sub(hash_idx + 1),
  }, nil
end

local function escape_markdown_spaces(text)
  return text:gsub(" ", "%%20")
end

-- Window/Buffer Management
local function is_special_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype

  local special_types = { "neo-tree", "lazy", "packer", "vim" }
  for _, ft in ipairs(special_types) do
    if filetype == ft then
      return true, ft
    end
  end

  if bufname:find "^diffview" or bufname:find "DAP" or bufname:find "dap" then
    return true, "special_window"
  end

  return false, nil
end

local function close_special_buffer(special_type)
  local close_commands = {
    ["neo-tree"] = function()
      vim.cmd.NeoTreeClose()
    end,
    ["lazy"] = function()
      vim.cmd.quit()
    end,
    ["packer"] = function()
      vim.cmd.close()
    end,
    ["vim"] = function()
      vim.cmd.quit()
    end,
    ["special_window"] = function()
      local bufname = vim.fn.bufname()
      if bufname:find "^diffview" then
        vim.cmd.DiffviewClose()
      else
        vim.cmd.close { bang = true }
      end
    end,
  }

  local cmd = close_commands[special_type]
  if cmd then
    cmd()
  end
end

local function resize_window(direction, amount)
  local cmd = (direction == "horizontal") and "resize" or "vertical resize"
  vim.cmd(string.format("%s %s%d", cmd, amount > 0 and "+" or "", amount))
end

-- ============================================================================
-- Window & Buffer Navigation
-- ============================================================================
-- Use Ctrl+hjkl instead of Ctrl+w+hjkl for faster window switching
-- Note: Avoid <Tab> mappings as Ctrl+i and <Tab> are equivalent in normal mode
-- vim.keymap.set("n", "<c-h>", "<c-w>h", { desc = "Window left" })
-- vim.keymap.set("n", "<c-l>", "<c-w>l", { desc = "Window right" })
-- vim.keymap.set("n", "<c-j>", "<c-w>j", { desc = "Window down" })
-- vim.keymap.set("n", "<c-k>", "<c-w>k", { desc = "Window up" })
vim.keymap.set("n", "<space><space>", "<c-^>", { desc = "Last buffer" })

-- ============================================================================
-- Core Editing Keymaps
-- ============================================================================
vim.keymap.set("i", "<c-d>", "<del>", { desc = "Delete forward" })
vim.keymap.set("i", "<c-_>", "<c-k>", { desc = "Digraph" })

vim.keymap.set("n", "<space>p", 'viw"0p', { desc = "Paste and Store Register 0" })
vim.keymap.set("n", "<space>y", "yiw", { desc = "Yank inner word" })

-- Paste over selected text without yanking it
-- 当你在可视模式下选中一段文本后，按下p键时，它将删除选中的文本，并将其粘贴到当前光标位置的下一行。
-- 同时，它会将粘贴的文本放入黑洞寄存器（"_），这意味着它不会影响你之前的剪贴板内容。
vim.keymap.set("v", "p", '"_dP', { silent = true })

vim.keymap.set({ "c", "i" }, "<C-a>", "<home>", { desc = "Move cursor to beginning of line" })
vim.keymap.set({ "c", "i" }, "<c-e>", "<end>", { desc = "Move cursor to end of line" })

vim.keymap.set("i", "jj", "<ESC>", { desc = "Exit insert mode" })
vim.keymap.set("n", "W", ":w!<cr>", { desc = "Save file" })

-- Yank to end of line
vim.keymap.set("n", "Y", "y$", { silent = true })

-- Cancel search highlighting with ESC
vim.keymap.set("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", { silent = true })

-- ============================================================================
-- Visual Mode Operations
-- ============================================================================
vim.keymap.set("v", "<", "<gv", { silent = true, desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { silent = true, desc = "Indent right and reselect" })

-- Not include last whitespace character when $ in visual mode
vim.keymap.set("x", "$", "g_", { silent = true })

-- Quick visual mode shortcuts
vim.keymap.set("n", "vv", "V", { desc = "Visual line mode" })
vim.keymap.set("n", "vvv", "<C-V>", { desc = "Visual block mode" })

-- Select last pasted text
vim.keymap.set("n", "gV", "`[v`]", { desc = "Select last paste area" })

-- Search within visual selection
-- Usage: Select text in visual mode, press g/, then type search pattern
vim.keymap.set("x", "g/", "<Esc>/\\%V", { desc = "Search in visual selection" })

-- ============================================================================
-- Paste & Copy Operations
-- ============================================================================

local function paste_and_preserve_column()
  -- 获取当前光标的列位置
  local col = vim.fn.col "."
  local count = vim.v.count > 0 and vim.v.count or 1

  -- 复制当前行
  vim.cmd("normal! " .. "yy")

  -- 执行粘贴操作
  vim.cmd("normal! " .. count .. "p")

  -- 恢复光标的列位置
  vim.fn.cursor(vim.fn.line ".", col)
end

vim.keymap.set({ "n" }, "\\p", paste_and_preserve_column, { silent = true, desc = "Paste and Preserve Column" })

-- Smart home: toggle between first non-blank and line start
local function home()
  local head = (vim.api.nvim_get_current_line():find "[^%s]" or 1) - 1
  local cursor = vim.api.nvim_win_get_cursor(0)
  cursor[2] = cursor[2] == head and 0 or head
  vim.api.nvim_win_set_cursor(0, cursor)
end

vim.keymap.set("n", "0", home, { desc = "Smart home" })
vim.keymap.set({ "n", "i" }, "<home>", home, { desc = "Smart home" })

-- Replace all occurrences with last yanked text
-- Usage: After yanking text (y, yy, etc.), press g. to replace all occurrences in file
-- The <c-r>. inserts the contents of the default register into the search part
vim.keymap.set("n", "g.", ":%s//<c-r>./g<esc>", { desc = "Replace with last yanked text" })

-- Navigate edit history
vim.keymap.set("n", "g;", function()
  vim.cmd "silent normal! g;"
end, { silent = true, desc = "Last edit position in current file" })

vim.keymap.set("n", "g,", function()
  vim.cmd "silent normal! g,"
end, { silent = true, desc = "Next edit position in current file" })

-- ============================================================================
-- Tab Management
-- ============================================================================
vim.keymap.set("n", "\\tt", ":tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "\\tq", ":tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>to", ":tabonly<cr>", { desc = "Close other tabs" })

-- Toggle current buffer full-screen using :tabedit %
-- If already in a separate tab, close it and return to split view
vim.keymap.set({ "n", "t" }, "<m-e>", function()
  local current_buf = vim.api.nvim_get_current_buf()
  local tabs = vim.api.nvim_list_tabpages()
  local pos = vim.api.nvim_win_get_cursor(0)

  if #tabs > 1 then
    for _, tab in ipairs(tabs) do
      local win = vim.api.nvim_tabpage_get_win(tab)
      local buf = vim.api.nvim_win_get_buf(win)

      if buf == current_buf and tab ~= vim.api.nvim_get_current_tabpage() then
        vim.api.nvim_win_set_cursor(win, pos)
        vim.cmd.tabclose()
        return
      end
    end
  end

  local file_path = vim.api.nvim_buf_get_name(current_buf)
  if file_path == "" then
    vim.notify("Cannot edit buffer: no file name", vim.log.levels.WARN)
    return
  end
  vim.cmd("tabedit " .. vim.fn.fnameescape(file_path))

  local win = vim.api.nvim_get_current_win()
  local line_count = vim.api.nvim_buf_line_count(current_buf)
  local line = math.min(pos[1], line_count)
  vim.api.nvim_win_set_cursor(win, { line, pos[2] })
end, { desc = "Toggle buffer full-screen" })

-- ============================================================================
-- Window Resizing
-- ============================================================================
vim.keymap.set("n", "<space>=", function()
  resize_window("horizontal", config.resize_horizontal_step)
end, { desc = "Increase window height" })

vim.keymap.set("n", "<space>-", function()
  resize_window("horizontal", -config.resize_horizontal_step)
end, { desc = "Decrease window height" })

vim.keymap.set("n", "<space>.", function()
  resize_window("vertical", config.resize_vertical_step)
end, { desc = "Increase window width" })

vim.keymap.set("n", "<space>,", function()
  resize_window("vertical", -config.resize_vertical_step)
end, { desc = "Decrease window width" })

vim.keymap.set("n", "<space>v.", function()
  resize_window("vertical", config.resize_vertical_step)
end, { desc = "Increase window width (alt)" })

vim.keymap.set("n", "<space>v,", function()
  resize_window("vertical", -config.resize_vertical_step)
end, { desc = "Decrease window width (alt)" })

vim.keymap.set("n", "<space>vv", ":vsplit<CR>", { desc = "Vertical split" })
vim.keymap.set("n", "<space>ss", ":split<CR>", { desc = "Horizontal split" })

-- ============================================================================
-- Buffer Management
-- ============================================================================
vim.keymap.set({ "n", "t" }, "\\bp", function()
  vim.cmd "bprevious"
end, { desc = "Previous buffer" })

vim.keymap.set({ "n", "t" }, "\\bn", function()
  vim.cmd "bnext"
end, { desc = "Next buffer" })

-- Quit window with smart behavior
local function quit_window()
  -- Check for special buffers first
  local is_special, special_type = is_special_buffer(0)
  if is_special then
    close_special_buffer(special_type)
    return
  end

  -- Get window and buffer counts
  local buf_count = #vim.fn.getbufinfo { buflisted = 1 }
  local win_count = #vim.api.nvim_list_wins()

  -- Decision logic
  if buf_count > 1 and win_count > 1 then
    vim.cmd.close { bang = true }
  elseif buf_count > 1 then
    vim.cmd.bdelete { bang = true }
  else
    vim.cmd.quit { bang = true }
  end
end

vim.keymap.set("n", "\\q", quit_window, { silent = true, desc = "Quit window" })

-- Close unused buffers (those without 'bufpersist' marker)
vim.keymap.set("n", "<space>cu", function()
  local curbufnr = vim.api.nvim_get_current_buf()
  local buflist = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(buflist) do
    local buftype = vim.bo[bufnr].buftype
    if
      vim.bo[bufnr].buflisted
      and bufnr ~= curbufnr
      and (vim.fn.getbufvar(bufnr, "bufpersist") ~= 1)
      and buftype ~= "terminal"
    then
      vim.cmd("bd " .. tostring(bufnr))
    end
  end

  -- Close DAP windows
  local windows = vim.api.nvim_list_wins()
  for _, winid in ipairs(windows) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname:find "DAP" or bufname:find "dap" then
      vim.api.nvim_win_close(winid, true)
    end
  end
end, { silent = true, desc = "Close unused buffers" })

-- ============================================================================
-- Preview Window Integration (vim-preview plugin)
-- ============================================================================
-- <m-;>: Open/jump to preview window
-- <m-:>: Close preview window
local first_init_window = {}
vim.keymap.set("n", "<m-;>", function()
  local winid = vim.api.nvim_get_current_win()
  local tabid = vim.api.nvim_get_current_tabpage()
  local winid_str = tostring(winid)
  local tabid_str = tostring(tabid)
  local preview_id = vim.fn["preview#preview_check"]()
  local key = winid_str .. ":" .. tabid_str
  vim.cmd "PreviewTag"
  -- preview_id == 0 means no preview window
  if not first_init_window[key] or preview_id == 0 then
    vim.cmd "wincmd p"
    first_init_window[key] = true
  end
end, { desc = "Open/jump to preview window" })

vim.keymap.set("n", "<m-:", ":PreviewClose<CR>", { desc = "Close preview window" })

-- Swap buffers between current window and preview window
vim.keymap.set("n", "<leader>sa", function()
  local preview_id = vim.fn["preview#preview_check"]()
  if preview_id == 0 then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local ids = vim.fn["preview#window_find"](preview_id)
  local preview_winnr = ids[1]

  vim.cmd(tostring(preview_winnr) .. "wincmd w")
  local preview_winid = vim.api.nvim_get_current_win()
  local preview_bufnr = vim.api.nvim_win_get_buf(preview_winid)

  vim.api.nvim_win_set_buf(winid, preview_bufnr)
  vim.api.nvim_win_set_buf(preview_winid, bufnr)
end, { desc = "Swap preview buffers" })

-- Swap windows
vim.keymap.set("n", "<leader>wx", function()
  local winid = vim.api.nvim_get_current_win()
  vim.cmd "wincmd x"
  vim.api.nvim_set_current_win(winid)
end, { desc = "Swap windows" })

-- ============================================================================
-- Quickfix & Async Operations
-- ============================================================================
vim.g.asyncrun_open = config.asyncrun_height
vim.g.asyncrun_bell = 1

vim.keymap.set("n", "<space>qf", ":call asyncrun#quickfix_toggle(20)<cr>", { desc = "Quickfix toggle" })
vim.keymap.set("n", "g2", ":AsyncTask grep-todo<CR>", { desc = "Grep todo" })

-- ============================================================================
-- Markdown Utilities
-- ============================================================================
-- Copy current line as markdown reference link
local function copy_with_prefix()
  -- Validate: has current line
  local line_text = vim.fn.getline "."
  if line_text == "" then
    vim.notify("Current line is empty", vim.log.levels.WARN)
    return
  end

  -- Validate: is markdown header
  local header, err = trim_markdown_header(line_text)
  if not header then
    vim.notify(err or "Invalid header format", vim.log.levels.WARN)
    return
  end

  -- Validate: has file name
  local file_path = vim.fn.expand "%:p"
  if file_path == "" then
    vim.notify("No file name", vim.log.levels.WARN)
    return
  end

  -- Build and copy link
  local file_name = vim.fn.expand "%:t"
  local link = string.format("[%s](%s#%s)", file_name, file_path, header)
  vim.fn.setreg('"', link)
  vim.notify("Copied: " .. link, vim.log.levels.INFO)
end

vim.keymap.set("n", "\\cy", copy_with_prefix, { silent = true, desc = "Copy with markdown reference link" })

-- Paste markdown reference link as relative path
local function paste_regester()
  local content = vim.fn.getreg '"'

  if content == "" then
    vim.notify("Empty register", vim.log.levels.WARN)
    return
  end

  -- Parse markdown link
  local link_data, parse_err = parse_markdown_link(content)
  if not link_data then
    vim.notify(parse_err or "Invalid link format", vim.log.levels.ERROR)
    return
  end

  -- Validate: has current file
  local current_file_abs_path = vim.fn.expand "%:p"
  if current_file_abs_path == "" then
    vim.notify("No file name", vim.log.levels.WARN)
    return
  end

  -- Calculate relative path
  local utils = require "utils"
  local current_file_name = vim.fn.expand "%:t"
  local current_file_dir = vim.fn.fnamemodify(current_file_abs_path, ":h")

  local relative_path
  if current_file_abs_path == link_data.file_path then
    relative_path = "./" .. current_file_name
  else
    relative_path = utils.relative_path(current_file_dir, link_data.file_path)
  end

  -- Build final link with escaped spaces
  local escaped_header = escape_markdown_spaces(link_data.header)
  local escaped_path = escape_markdown_spaces(relative_path)
  local full_link = string.format("[%s](%s#%s)", link_data.header, escaped_path, escaped_header)

  -- Paste and restore register
  vim.fn.setreg('"', full_link)
  vim.cmd 'normal! "0p'
  vim.fn.setreg('"', content)
end

vim.keymap.set("n", "\\cp", paste_regester, { silent = true, desc = "Paste markdown" })

-- ============================================================================
-- Miscellaneous Utilities
-- ============================================================================
-- Change colorscheme
local function change_color()
  local file = config.nvim_config_path .. "lua/style.lua"
  vim.cmd("source " .. file)
end

vim.keymap.set("n", "g3", change_color, { desc = "Change colorscheme" })

-- Source current nvim config file
vim.keymap.set("n", "<leader>ll", function()
  local file = vim.fn.expand "%:p"
  if file:find(vim.fn.expand(config.nvim_config_path), 1, true) == 1 then
    vim.cmd("source " .. file)
    print("source " .. file .. " done")
  end
end, { desc = "Source current file" })

-- Change to root directory
vim.keymap.set("n", "<space>tc", function()
  local utils = require "utils"
  utils.change_to_current_buffer_root_dir()
  vim.cmd.redraw()
  local root = utils.find_root_dir()
  vim.notify("now is in " .. root)
end, { silent = true, desc = "cd to root" })

-- Create diary file
local function mk_diary_file()
  local now = os.date "%Y-%m-%d"
  local year = os.date "%Y"
  local dir = config.diary_base_path .. year
  local file = dir .. "/" .. now .. ".md"
  vim.cmd.edit(file)
end

vim.keymap.set("n", "<leader>md", mk_diary_file, { desc = "Create diary file" })

-- Retab directory recursively
local function retab_directory()
  local current_dir = vim.fn.expand "%:p:h"

  local function retab_file(file)
    if vim.fn.isdirectory(file) == 0 then
      vim.cmd.edit(file)
      vim.cmd "set expandtab | retab"
      vim.cmd.write()
    end
  end

  local function retab_directory_helper(dir)
    local files = vim.fn.readdir(dir)
    for _, file in ipairs(files) do
      if file ~= "." and file ~= ".." then
        local full_path = dir .. "/" .. file
        if vim.fn.isdirectory(full_path) ~= 0 then
          retab_directory_helper(full_path)
        else
          retab_file(full_path)
        end
      end
    end
  end

  retab_directory_helper(current_dir)
end

vim.keymap.set("n", "<leader>rt", retab_directory, { silent = true, desc = "Retab directory" })

-- ============================================================================
-- Smart Jump Over Closing/Opening Characters
-- ============================================================================
-- Smart jump over closing characters in insert mode
-- Usage: Press <C-l> in insert mode to jump to the next closing character
-- Example: After typing `foo(bar|)` where | is cursor, <C-l> moves cursor past the )
vim.keymap.set("i", "<C-l>", function()
  local closers = { ")", "]", "}", ">", "'", '"', "`", "," }
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local after = line:sub(col + 1, -1)

  local closer_col = #after + 1
  local closer_i = nil

  for i, closer in ipairs(closers) do
    local cur_index, _ = after:find(closer, 1, true)
    if cur_index and (cur_index < closer_col) then
      closer_col = cur_index
      closer_i = i
    end
  end

  if closer_i then
    vim.api.nvim_win_set_cursor(0, { row, col + closer_col })
  else
    vim.api.nvim_win_set_cursor(0, { row, col + 1 })
  end
end, { desc = "Move over a closing element" })

-- Smart jump over opening characters in insert mode (backwards)
-- Usage: Press <C-h> in insert mode to jump to before the nearest opening character
vim.keymap.set("i", "<C-h>", function()
  local openers = { "(", "[", "{", "<", "'", '"', "`", "," }
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local before = line:sub(1, col)

  local opener_col = 0
  local opener_i = nil

  for i, opener in ipairs(openers) do
    local pos = 1
    local last_found = nil
    while true do
      local found = string.find(before, opener, pos, true)
      if not found then
        break
      end
      last_found = found
      pos = found + 1
    end

    if last_found and last_found > opener_col then
      opener_col = last_found
      opener_i = i
    end
  end

  if opener_i then
    vim.api.nvim_win_set_cursor(0, { row, opener_col - 1 })
  else
    vim.api.nvim_win_set_cursor(0, { row, math.max(0, col - 1) })
  end
end, { desc = "Move before an opening element" })

-- ============================================================================
-- Auto-commands
-- ============================================================================
-- Buffer persistence system
local augroup_id = vim.api.nvim_create_augroup("startup", {
  clear = false,
})

local function persistbuffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.fn.setbufvar(bufnr, "bufpersist", 1)
end

vim.api.nvim_create_autocmd({ "BufRead" }, {
  group = augroup_id,
  pattern = { "*" },
  callback = function()
    vim.api.nvim_create_autocmd({ "InsertEnter", "BufModifiedSet" }, {
      buffer = 0,
      once = true,
      callback = function()
        persistbuffer()
      end,
    })
  end,
})

-- Delete [No Name] buffers automatically
vim.api.nvim_create_autocmd("BufHidden", {
  desc = "Delete [No Name] buffers",
  callback = function(event)
    if event.file == "" and vim.bo[event.buf].buftype == "" and not vim.bo[event.buf].modified then
      vim.schedule(function()
        pcall(vim.api.nvim_buf_delete, event.buf, {})
      end)
    end
  end,
})

-- Jump to last edit position on opening file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  pattern = "*",
})
-- https://www.reddit.com/r/neovim/comments/1ormbls/keymaps_to_yank_file_namepath/
-- Copy file paths to system clipboard and vim register
-- <leader>yp: Copy relative path (e.g., "nvim/.config/nvim/lua/keymaps.lua")
vim.keymap.set("n", "<leader>yr", function()
  local path = vim.fn.expand "%:."
  vim.fn.setreg("+", path) -- System clipboard
  vim.fn.setreg('"', path) -- Vim default register
end, { desc = "Copy relative path" })

-- <leader>yP: Copy absolute path (e.g., "/Users/name/project/file.lua")
vim.keymap.set("n", "<leader>ya", function()
  local path = vim.fn.expand "%:p"
  vim.fn.setreg("+", path) -- System clipboard
  vim.fn.setreg('"', path) -- Vim default register
end, { desc = "Copy absolute path" })

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  callback = function()
    vim.highlight.on_yank { higroup = "Visual", timeout = 300 }
  end,
})

vim.keymap.set(
  "n",
  "\\gx",
  ":belowright split | lua vim.lsp.buf.definition()<CR>",
  { desc = "Go to definition with horizontal split" }
)
vim.keymap.set(
  "n",
  "\\gv",
  ":vsplit | lua vim.lsp.buf.definition()<CR>",
  { desc = "Go to definition with vertical split" }
)
vim.keymap.set("n", "\\gt", ":tab split | lua vim.lsp.buf.definition()<CR>", { desc = "Go to definition with new tab" })
