local u = require "util"
-- https://github.com/Allaman/nvim/blob/main/lua/mappings.lua
local default_options = { noremap = true, silent = true }

-- 窗口快捷键映射
-- why not use tab, because of c-i is the same as tab in normal mode
-- which means when you set <tab>h, when use c-i, it will wait timeout time, which is slow
u.map("n", "<c-h>", "<c-w>h", { desc = "Window left" })
u.map("n", "<c-l>", "<c-w>l", { desc = "Window right" })
u.map("n", "<c-j>", "<c-w>j", { desc = "Window down" })
u.map("n", "<c-k>", "<c-w>k", { desc = "Window up" })
u.map("n", "<space><space>", "<c-^>", { desc = "Last buffer" })

-- 编辑模式
u.map("i", "<c-a>", "<home>")
u.map("i", "<c-e>", "<end>")
u.map("i", "<c-d>", "<del>")
u.map("i", "<c-_>", "<c-k>")

u.map("n", "<space>p", 'viw"0p', { desc = "Paste and Store Register 0" })
u.map("n", "<space>y", "yiw")
-- paste over currently selected text without yanking it
-- 当你在可视模式下选中一段文本后，按下p键时，它将删除选中的文本，并将其粘贴到当前光标位置的下一行。
-- 同时，它会将粘贴的文本放入黑洞寄存器（"_），这意味着它不会影响你之前的剪贴板内容。
-- 一半操作是使用viw命令选中文本，另一半是使用p命令粘贴文本，p粘贴的文本是之前复制的文本
u.map("v", "p", '"_dP', default_options)

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

vim.api.nvim_set_keymap("c", "<C-a>", "<home>", { noremap = true })
vim.api.nvim_set_keymap("c", "<c-e>", "<end>", { noremap = true })

u.map("v", "<", "<gv", default_options)
u.map("v", ">", ">gv", default_options)
-- not include last whitespace character
u.map("x", "$", "g_", default_options)

vim.keymap.set({ "n" }, "vv", "V", { noremap = true })
vim.keymap.set({ "n" }, "vvv", "<C-V>", { noremap = true })

-- Cancel search highlighting with ESC
u.map("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", default_options)

-- yank
u.map("n", "Y", "y$", default_options)

u.map("n", "W", ":w!<cr>")
u.map("i", "jj", "<ESC>")

-- u.map("n", "<leader>bn", ":bn<cr>")
-- u.map("n", "<leader>bp", ":bp<cr>")

u.map("n", "\\tt", ":tabnew<cr>")
u.map("n", "\\tq", ":tabclose<cr>")
-- u.map("n", "\\tn", ":tabnext<cr>")
-- u.map("n", "\\tp", ":tabprev<cr>")
u.map("n", "<leader>to", ":tabonly<cr>")

u.map("n", "<space>=", ":resize +3<cr>")
u.map("n", "<space>-", ":resize -3<cr>")
u.map("n", "<space>,", ":vertical resize -5<cr>")
u.map("n", "<space>.", ":vertical resize +5<cr>")

-- vim-preview - 快速预览标签定义和跳转
-- <m-;>: 打开预览窗口，如果已存在则跳转到预览窗口，否则创建并跳转
-- <m-:>: 关闭预览窗口
local first_init_window = {}
vim.keymap.set("n", "<m-;>", function()
  -- jump back to last window - 跳转到最后一个窗口
  -- Get the current windowid and tabid - 获取当前窗口ID和标签页ID
  local winid = vim.api.nvim_get_current_win()
  local tabid = vim.api.nvim_get_current_tabpage()
  local winid_str = tostring(winid)
  local tabid_str = tostring(tabid)
  local pid = vim.fn["preview#preview_check"]()
  local key = winid_str .. ":" .. tabid_str
  vim.cmd "PreviewTag" -- 打开预览窗口显示光标下的标签定义
  -- pid == 0 means no preview window - pid为0表示没有预览窗口
  if not first_init_window[key] or pid == 0 then
    vim.cmd "wincmd p" -- 跳转到上一个窗口（预览窗口）
    first_init_window[key] = true
  end
end)
u.map("n", "<m-:", ":PreviewClose<CR>") -- 关闭预览窗口

-- 自动打开 quickfix window ，高度为 10
vim.g.asyncrun_open = 10

-- 任务结束时候响铃提醒
vim.g.asyncrun_bell = 1
-- quickfix 手动打开
u.map("n", "<space>qf", ":call asyncrun#quickfix_toggle(20)<cr>", { desc = "quickfix toggle" })

local function home()
  local head = (vim.api.nvim_get_current_line():find "[^%s]" or 1) - 1
  local cursor = vim.api.nvim_win_get_cursor(0)
  cursor[2] = cursor[2] == head and 0 or head
  vim.api.nvim_win_set_cursor(0, cursor)
end

vim.keymap.set("n", "0", home, { desc = "home" }, home)
vim.keymap.set({ "n", "i" }, "<home>", home)

local change_color = function()
  local file = "~/.config/nvim/lua/style.lua"
  local cmd = ":source " .. file
  vim.cmd(cmd)
end

vim.keymap.set("n", "g2", ":AsyncTask grep-todo<CR>")
vim.keymap.set("n", "g3", function()
  change_color()
end, { desc = "show change colorscheme" })
vim.keymap.set("n", "<space>vv", ":vsplit<CR>", { desc = "vsplit" })
vim.keymap.set("n", "<space>ss", ":split<CR>", { desc = "split" })

vim.keymap.set("n", "<leader>ll", function()
  local file = vim.fn.expand "%:p"
  if file:find(vim.fn.expand "~/.config/nvim/", 1, true) == 1 then
    local cmd = ":source " .. file
    vim.cmd(cmd)
    print(cmd .. " done")
  end
end, { desc = "source current file" })

local id = vim.api.nvim_create_augroup("startup", {
  clear = false,
})

local persistbuffer = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.fn.setbufvar(bufnr, "bufpersist", 1)
end

vim.api.nvim_create_autocmd({ "BufRead" }, {
  group = id,
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

vim.keymap.set("n", "<space>cu", function()
  local curbufnr = vim.api.nvim_get_current_buf()
  local buflist = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(buflist) do
    -- get buffer type of each buffer
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
  local function display_all_windows()
    local windows = vim.api.nvim_list_wins()
    for _, winid in ipairs(windows) do
      local bufnr = vim.api.nvim_win_get_buf(winid)
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      -- buf name 中包含 DAP
      if bufname:find "DAP" then
        vim.api.nvim_win_close(winid, true)
      end
      if bufname:find "dap" then
        vim.api.nvim_win_close(winid, true)
      end
      -- local win_info = string.format("Window ID: %d, Buffer: %s\n", winid, bufname)
      -- print(win_info)
    end
  end
  display_all_windows()
end, { silent = true, desc = "Close unused buffers" })

function retab_directory()
  local current_dir = vim.fn.expand "%:p:h"

  local function retab_file(file)
    if vim.fn.isdirectory(file) == 0 then
      vim.api.nvim_command(":e " .. file)
      vim.api.nvim_command ":set expandtab | retab"
      vim.api.nvim_command ":w"
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

local function quit_window()
  local buf_total_num = vim.fn.len(vim.fn.getbufinfo { buflisted = 1 })
  local buf_name = vim.fn.bufname()
  if vim.o.filetype == "neo-tree" then
    vim.api.nvim_command "NeoTreeClose"
    return
  end
  if vim.bo.filetype == "lazy" then
    vim.api.nvim_command "quit"
    return
  end
  if vim.o.filetype == "vim" then
    vim.api.nvim_command "quit"
  end
  if vim.o.filetype == "packer" then
    vim.api.nvim_command "close"
  end
  if buf_name:find "^diffview" then
    vim.api.nvim_command "DiffviewClose"
    -- vim.api.nvim_command("bdelete %s"):format(buf_id)
  end
  -- Get the number of windows
  --
  local window_count = vim.api.nvim_list_wins()
  if buf_total_num ~= 1 and #window_count > 1 then
    -- close means `close window`
    vim.api.nvim_command "close!"
  elseif buf_total_num ~= 1 then
    vim.api.nvim_command "bdelete!"
  else
    vim.api.nvim_command "quit!"
  end
end

vim.keymap.set("n", "\\q", function()
  quit_window()
end, { silent = true, desc = "Quit window" })

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

local mk_diary_file = function()
  local now = os.date "%Y-%m-%d"
  local year = os.date "%Y"
  local dir = "~/work/notes/Calendar/Daily Notes/" .. year
  local file = dir .. "/" .. now .. ".md"
  vim.api.nvim_command(":e " .. file)
end

vim.keymap.set("n", "<leader>md", mk_diary_file, { desc = "mk diary file" })

vim.keymap.set("n", "<space>tc", function()
  local utils = require "utils"
  utils.change_to_current_buffer_root_dir()
  vim.cmd.redraw()
  local root = utils.find_root_dir()
  vim.notify("now is in " .. root)
end, { silent = true, desc = "cd to root" })

local function copy_with_prefix()
  local select = vim.fn.getline "."
  -- 输出选择的文本
  print("select is ", vim.inspect(select))

  -- get select array first element

  local selection = select
  print("selection is ", selection)
  local util = require "utils"
  print("util is ", vim.inspect(util))

  -- 删除两端的空白字符
  selection = vim.trim(selection)
  -- 如果选择的文本以#开头，则selection删除多个#
  if string.sub(selection, 1, 1) == "#" then
    -- trim开头的多个#
    selection = util.remove_leading_char(selection, "#")
  else
    vim.notify "selection must start with #"
    return
  end

  -- 移除最后不可打印字符
  selection = string.gsub(selection, "%c", "")

  selection = vim.trim(selection)
  if selection == "" then
    print "selection is empty"
    return
  end

  -- 获取当前文件的绝对路径
  local current_file_abs_path = vim.fn.expand "%:p"
  if current_file_abs_path == "" then
    print "No file name"
    return
  end
  local current_file_name = vim.fn.expand "%:t"
  print("current file is ", current_file_abs_path)

  -- 添加前缀
  local prefixed = "[" .. current_file_name .. "]" .. "(" .. current_file_abs_path .. "#" .. selection .. ")"

  -- 放入寄存器
  vim.fn.setreg('"', prefixed)
  print("Copied to clipboard: " .. prefixed)
end

vim.keymap.set("n", "\\cy", function()
  copy_with_prefix()
end, { silent = true, desc = "copy with markdown reference link" })

-- 定义一个函数获取内容并粘贴
local function paste_regester()
  local content = vim.fn.getreg '"'

  if content ~= "" then
    -- content is `[2023-12-13.md](2023-12-13.md#test)`
    -- 获取() 中的内容
    local start_index = string.find(content, "%(")
    local end_index = string.find(content, "%)")
    local selection = string.sub(content, start_index + 1, end_index - 1)
    start_index = string.find(selection, "#")
    assert(start_index ~= nil)
    -- including #
    local header_content = string.sub(selection, start_index + 1)
    local dest_file_path = string.sub(selection, 1, start_index - 1)

    -- 获取当前文件的绝对路径
    local current_file_abs_path = vim.fn.expand "%:p"
    if current_file_abs_path == "" then
      print "No file name"
      return
    end
    print("current file is ", current_file_abs_path)
    local utils = require "utils"

    local current_file_name = vim.fn.expand "%:t"
    local current_file_dir = vim.fn.fnamemodify(current_file_abs_path, ":h")
    local relative_path = ""
    if current_file_abs_path == dest_file_path then
      relative_path = "./" .. current_file_name
    else
      relative_path = utils.relative_path(current_file_dir, dest_file_path)
    end

    -- 将header_content中的空格替换为%20
    local escaped_header_content = string.gsub(header_content, " ", "%%20")
    local relative_escaped_path = string.gsub(relative_path, " ", "%%20")
    local full_link = "["
      .. header_content
      .. "]"
      .. "("
      .. relative_escaped_path
      .. "#"
      .. escaped_header_content
      .. ")"
    print("full link is ", full_link)

    vim.fn.setreg('"', full_link)
    vim.api.nvim_command 'normal! "0p'
    vim.fn.setreg('"', content)
  else
    vim.notify "empty resgister"
  end
end

vim.keymap.set("n", "\\cp", function()
  paste_regester()
end, { noremap = true, silent = true, desc = "paste markdown" })

-- Jump to last edit position on opening file
--
-- `au BufReadPost` that triggers when a buffer is read after the file has been loaded.
-- The condition checks if the file path (`expand('%:p')`) does not contain `.git/`
-- if the line number stored in the last known cursor position (`line("'\"")`) is valid (greater than 1 and less than or equal to the last line of the file).
-- If both conditions are met, it executes a normal mode command (`exe "normal! g'\""`) to move the cursor to the last known position.
vim.cmd [[
  au BufReadPost * if expand('%:p') !~# '\m/\.git/' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
]]

-- todo
vim.keymap.set("n", "<leader>sa", function()
  -- 交换两个窗口的中的buffer
  local pid = vim.fn["preview#preview_check"]()
  if pid == 0 then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local ids = vim.fn["preview#window_find"](pid)
  local preview_winnr = ids[1]

  vim.cmd(tostring(preview_winnr) .. "wincmd w")
  local preview_winid = vim.api.nvim_get_current_win()
  print("preview_winid is ", preview_winid)
  local preview_bufnr = vim.api.nvim_win_get_buf(preview_winid)
  print("preview_bufnr is ", preview_bufnr)

  vim.api.nvim_win_set_buf(winid, preview_bufnr)
  vim.api.nvim_win_set_buf(preview_winid, bufnr)
end, { desc = "swap preivew buffers" })

vim.keymap.set("n", "<leader>wx", function()
  local winid = vim.api.nvim_get_current_win()
  vim.cmd "wincmd x"
  vim.api.nvim_set_current_win(winid)
end, { desc = "swap windows" })

vim.keymap.set({ "n", "t" }, "\\bp", function()
  vim.cmd "bprevious"
end, { desc = "previous buffer" })

vim.keymap.set({ "n", "t" }, "\\bn", function()
  vim.cmd "bnext"
end, { desc = "next buffer" })

vim.keymap.set("n", "<space>v.", function()
  vim.cmd ":vertical resize +5<cr>"
end, { desc = "vertical size increase" })

-- 假设你粘贴了一段代码或文本，然后想要快速选择这段内容进行编辑，只需按下 `gV`，Neovim 就会自动选择你刚刚粘贴的内容。
vim.keymap.set("n", "gV", "`[v`]", { desc = "select last paste area" })

-- 1. Enter visual mode and select a block of text.
-- 2. Press `g/`.
-- 3. Neovim will exit visual mode and start a search that is limited to the selected text.
-- * https://www.reddit.com/r/neovim/comments/1ixsk40/share_your_tips_and_tricks_in_neovim/
vim.keymap.set("x", "g/", "<Esc>/\\%V")

vim.keymap.set("n", "<space>v,", function()
  vim.cmd ":vertical resize -5<cr>"
end, { desc = "vertical size decrease" })

vim.keymap.set("n", "g;", function()
  vim.cmd "silent normal! g;"
end, { silent = true, desc = "last edit position in current file" })

vim.keymap.set("n", "g,", function()
  vim.cmd "silent normal! g,"
end, { silent = true, desc = "next edit position in current file" })
