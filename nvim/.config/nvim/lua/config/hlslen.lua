local api = vim.api
local fn = vim.fn
local kopts = { noremap = true, silent = true }

--- 大文件阈值
local MAX_LINES = 100000
local MAX_FSIZE = 10485760 -- 10MB

--- 判断当前 buffer 是否为大文件
local function is_large_file()
  local bufnr = api.nvim_get_current_buf()
  local line_count = api.nvim_buf_line_count(bufnr)
  if line_count > MAX_LINES then
    return true
  end
  local fsize = fn.getfsize(api.nvim_buf_get_name(bufnr))
  if fsize > MAX_FSIZE then
    return true
  end
  return false
end

--- 根据文件大小动态启用/禁用 hlslens
local function maybe_toggle_hlslens()
  local hlslens = require "hlslens"
  if is_large_file() then
    hlslens.disable()
  else
    hlslens.enable()
  end
end

require("hlslens").setup {
  auto_enable = false,
  override_lens = function(render, posList, nearest, idx, relIdx)
    local sfw = vim.v.searchforward == 1
    local indicator, text, chunks
    local absRelIdx = math.abs(relIdx)
    if absRelIdx > 1 then
      indicator = ("%d%s"):format(absRelIdx, sfw ~= (relIdx > 1) and "▲" or "▼")
    elseif absRelIdx == 1 then
      indicator = sfw ~= (relIdx == 1) and "▲" or "▼"
    else
      indicator = ""
    end

    local lnum, col = unpack(posList[idx])
    if nearest then
      local cnt = #posList
      if indicator ~= "" then
        text = ("[%s %d/%d]"):format(indicator, idx, cnt)
      else
        text = ("[%d/%d]"):format(idx, cnt)
      end
      chunks = { { " ", "Ignore" }, { text, "HlSearchLensNear" } }
    else
      text = ("[%s %d]"):format(indicator, idx)
      chunks = { { " ", "Ignore" }, { text, "HlSearchLens" } }
    end
    render.setVirt(0, lnum - 1, col - 1, chunks, nearest)
  end,
}

--- 在文件打开/切换时动态控制 hlslens
local group = api.nvim_create_augroup("HlslensLargeFile", { clear = true })
api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufEnter" }, {
  group = group,
  callback = maybe_toggle_hlslens,
})

--- 立即检查当前 buffer（处理 VeryLazy 加载时已存在的 buffer）
maybe_toggle_hlslens()

vim.api.nvim_set_keymap(
  "n",
  "n",
  [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
  kopts
)
vim.api.nvim_set_keymap(
  "n",
  "N",
  [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
  kopts
)
vim.api.nvim_set_keymap("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
vim.api.nvim_set_keymap("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
vim.api.nvim_set_keymap("n", "g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
vim.api.nvim_set_keymap("n", "g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

vim.api.nvim_set_keymap("n", "<Leader>l", ":noh<CR>", kopts)
