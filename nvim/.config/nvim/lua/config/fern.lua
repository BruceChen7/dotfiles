-- fern.vim
u = require "util"
u.map("n", "ne", ":Fern .  -reveal=% <CR>")
u.map("n", "nE", ":Fern . -opener=vsplit -reveal=% <CR>")
u.map("n", "nc", ":Fern %:h  -reveal=% <CR>")
u.map("n", "nC", ":Fern %:h -opener=vsplit -reveal=% <CR>")
function init_fern()
  -- Define NERDTree like mappings
  vim.api.nvim_buf_set_keymap(0, "n", "o", "<Plug>(fern-action-open:edit)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "go", "<Plug>(fern-action-open:edit)<C-w>p", {})
  vim.api.nvim_buf_set_keymap(0, "n", "t", "<Plug>(fern-action-open:tabedit)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "T", "<Plug>(fern-action-open:tabedit)gT", {})
  vim.api.nvim_buf_set_keymap(0, "n", "i", "<Plug>(fern-action-open:split)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "gi", "<Plug>(fern-action-open:split)<C-w>p", {})
  vim.api.nvim_buf_set_keymap(0, "n", "s", "<Plug>(fern-action-open:vsplit)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "gs", "<Plug>(fern-action-open:vsplit)<C-w>p", {})
  vim.api.nvim_buf_set_keymap(0, "n", "ma", "<Plug>(fern-action-new-path)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "P", "gg", {})
  vim.api.nvim_buf_set_keymap(0, "n", "as", "<Plug>(fern-action-open:select)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "aa", "<Plug>(fern-action-new-file)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "C", "<Plug>(fern-action-enter)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "u", "<Plug>(fern-action-leave)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "r", "<Plug>(fern-action-reload)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "R", "gg<Plug>(fern-action-reload)<C-o>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "cd", "<Plug>(fern-action-cd)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "CD", "gg<Plug>(fern-action-cd)<C-o>", {})
  vim.api.nvim_buf_set_keymap(0, "n", "I", "<Plug>(fern-action-hidden)", {})
  vim.api.nvim_buf_set_keymap(0, "n", "q", ":quit<CR>", {})
  -- not using this, because i what use N to search
  vim.api.nvim_buf_set_keymap(0, "n", "N", "<NOP>", {})
  vim.api.nvim_buf_set_keymap(
    0,
    "n",
    "n",
    [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
    {}
  )
  vim.api.nvim_buf_set_keymap(
    0,
    "n",
    "N",
    [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
    {}
  )
end

vim.cmd [[
    augroup fern_custom
        autocmd!
        autocmd FileType fern lua init_fern()
    augroup END
]]

