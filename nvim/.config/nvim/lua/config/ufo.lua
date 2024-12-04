local fold_handler = function(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = (" 󰦸 %d "):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, { chunkText, hlGroup })
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2nd argument, need padding
      if curWidth + chunkWidth < targetWidth then
        suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, { suffix, "MoreMsg" })
  return newVirtText
end

require("ufo").setup {
  provider_selector = function(bufnr, filetype)
    if filetype == "markdown" then
      return { "treesitter", "indent" }
    end
    return "indent"
  end,
  fold_virt_text_handler = fold_handler,
  preview = {
    win_config = {
      border = { "", "─", "", "", "", "─", "", "" },
      winhighlight = "Normal:Folded",
      winblend = 0,
    },
    mappings = {
      scrollB = "<C-u>",
      scrollF = "<C-d>",
    },
  },
}

vim.o.foldcolumn = "1"
-- This sets the characters used for various visual elements.
-- For example, `foldopen:` and `foldclose:`
-- set the characters for open and close fold indicators.
vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
-- This sets the fold level to a high value (99),
-- which effectively means all folds are open by default.
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
-- This starts with all folds closed when opening a file.
vim.o.foldlevelstart = -1
-- 允许代码折叠
vim.o.foldenable = true

vim.keymap.set("n", "zR", function()
  vim.o.foldlevel = 10
  require("ufo").openAllFolds()
end, { desc = "Open All Folds" })
vim.keymap.set("n", "zM", function()
  vim.o.foldlevel = 10
  require("ufo").closeAllFolds()
end, { desc = "Close All Folds" })
vim.keymap.set("n", "K", function()
  local winid = require("ufo").peekFoldedLinesUnderCursor()
  if not winid then
    vim.lsp.buf.hover()
  end
end, { desc = "Peek Folded Lines" })
