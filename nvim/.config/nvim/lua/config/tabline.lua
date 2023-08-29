local u = require "util"
-- tab keymap
u.map("n", "\\t", ":tabnew<CR>")
u.map("n", "\\d", ":tabclose<cr>")
u.map("n", "\\1", ":tabn 1<cr>")
u.map("n", "\\2", ":tabn 2<cr>")
u.map("n", "\\3", ":tabn 3<cr>")
u.map("n", "\\4", ":tabn 4<cr>")
u.map("n", "\\5", ":tabn 5<cr>")
u.map("n", "\\6", ":tabn 6<cr>")
u.map("n", "\\7", ":tabn 7<cr>")
u.map("n", "\\8", ":tabn 8<cr>")
u.map("n", "\\9", ":tabn 9<cr>")
-- avoid slowly to wait to parse \\1
u.map("n", "\\0", ":tabn 10<cr>")

function quitWindow()
  local buf_total_num = vim.fn.len(vim.fn.getbufinfo { buflisted = 1 })
  local buf_name = vim.fn.bufname()
  if buf_name:find "^diffview" then
    vim.api.nvim_command "DiffviewClose"
    vim.api.nvim_command "VemTablineDelete"
  elseif buf_total_num ~= 1 then
    vim.api.nvim_command "VemTablineDelete"
  else
    vim.api.nvim_command "quit!"
  end
end

function quitWindow()
  local buf_total_num = vim.fn.len(vim.fn.getbufinfo { buflisted = 1 })
  local buf_name = vim.fn.bufname()
  if buf_name:find "^diffview" then
    vim.api.nvim_command "DiffviewClose"
    vim.api.nvim_command "VemTablineDelete"
  elseif buf_total_num ~= 1 then
    vim.api.nvim_command "VemTablineDelete"
  else
    vim.api.nvim_command "quit!"
  end
end

if vim.fn.exists ":VemTablineGo" then
  -- always show number
  vim.g.vem_tabline_show_number = "index"
  -- alway show tabline
  vim.g.vem_tabline_show = 2

  -- tab keymap
  u.map("n", "\\t", ":tabnew<CR>")
  u.map("n", "\\d", ":tabclose<cr>")
  u.map("n", "\\1", ":VemTablineGo 1<cr>")
  u.map("n", "\\2", ":VemTablineGo 2<cr>")
  u.map("n", "\\3", ":VemTablineGo 3<cr>")
  u.map("n", "\\4", ":VemTablineGo 4<cr>")
  u.map("n", "\\5", ":VemTablineGo 5<cr>")
  u.map("n", "\\6", ":VemTablineGo 6<cr>")
  u.map("n", "\\7", ":VemTablineGo 7<cr>")
  u.map("n", "\\8", ":VemTablineGo 8<cr>")
  u.map("n", "\\9", ":VemTablineGo 9<cr>")
  -- avoid slowly to wait to parse \\1
  u.map("n", "\\0", ":VemTablineGo 10<cr>")
  vim.cmd [[
        command -nargs=0 VemTablineDelete call vem_tabline#tabline.delete_buffer()
    ]]
  -- quit window
  u.map("n", "Q", ":lua quitWindow()<cr>")
end
