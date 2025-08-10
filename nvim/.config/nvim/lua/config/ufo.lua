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

local function handle_timestamp()
  -- Check if there's already a timestamp floating window
  if _G.timestamp_floating_win and vim.api.nvim_win_is_valid(_G.timestamp_floating_win) then
    -- Close the existing window
    vim.api.nvim_win_close(_G.timestamp_floating_win, false)
    _G.timestamp_floating_win = nil
    _G.timestamp_floating_buf = nil
    return true
  end

  -- Get the current word under cursor
  local current_word = vim.fn.expand "<cword>"

  -- Check if it's a Unix timestamp (digits only)
  if current_word:match "^%d+$" then
    local timestamp = tonumber(current_word)
    -- Check if it's a reasonable timestamp (between 1970 and 2100)
    if timestamp >= 631152000 and timestamp <= 4102444800 then -- Jan 1, 1990 to Jan 1, 2100
      -- Convert timestamp to local date
      local formatted_date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
      local content = {
        "Timestamp: " .. current_word,
        "Converted: " .. formatted_date,
        "Press K again to close",
      }

      -- Show in floating window
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

      local opts = {
        relative = "cursor",
        width = 40,
        height = 4,
        col = 0,
        row = 1,
        style = "minimal",
        border = "single",
        focusable = true,
        zindex = 100,
      }

      local win = vim.api.nvim_open_win(buf, false, opts)
      vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")

      -- Store the window ID and buffer ID
      _G.timestamp_floating_win = win
      _G.timestamp_floating_buf = buf

      -- Set buffer to be readonly
      vim.api.nvim_buf_set_option(buf, "modifiable", false)
      vim.api.nvim_buf_set_option(buf, "readonly", true)

      -- Create buffer-local keymap for focusing the window
      vim.api.nvim_buf_set_keymap(buf, "n", "K", "", {
        noremap = true,
        silent = true,
        callback = function()
          vim.api.nvim_set_current_win(win)
        end,
        desc = "Focus timestamp window",
      })
      return true
    end
  end

  -- Not a recognized timestamp, do nothing
  return false
end

vim.keymap.set("n", "K", function()
  local winid = require("ufo").peekFoldedLinesUnderCursor()
  if winid then
    return -- UFO fold preview was shown
  end

  -- Handle timestamp window
  handle_timestamp()

  -- If it's not a timestamp and no window was created, show LSP hover
  if not _G.timestamp_floating_win then
    vim.lsp.buf.hover()
  end
end, { desc = "Peek Folded Lines or Toggle Timestamp Window" })

vim.keymap.set("n", "zgj", function()
  local ufo = require "ufo"
  ufo.goNextClosedFold()
end, { desc = "go to next closed fold" })

vim.keymap.set("n", "zgk", function()
  local ufo = require "ufo"
  ufo.goPreviousClosedFold()
end, { desc = "go to preivous closed fold" })

vim.keymap.set("n", "zgK", function()
  local winid = require("ufo").peekFoldedLinesUnderCursor()
  if not winid then
    vim.lsp.buf.hover()
  end
end, { desc = "go to preivous closed fold" })
