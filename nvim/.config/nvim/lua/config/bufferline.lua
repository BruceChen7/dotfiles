local bufferline = require "bufferline"
bufferline.setup {
  options = {
    mode = "tabs",
    -- mode = "buffers", -- set to "tabs" to only show tabpages instead
    style_preset = bufferline.style_preset.default, -- or bufferline.style_preset.minimal,
    themable = true, -- allows highlight groups to be overriden i.e. sets highlights as default
    numbers = "ordinal",
    close_command = "bdelete! %d", -- can be a string | function, | false see "Mouse actions"
    right_mouse_command = "bdelete! %d", -- can be a string | function | false, see "Mouse actions"
    left_mouse_command = "buffer %d", -- can be a string | function, | false see "Mouse actions"
    middle_mouse_command = nil, -- can be a string | function, | false see "Mouse actions"
    indicator = {
      icon = "▎", -- this should be omitted if indicator style is not 'icon'
      style = "icon",
    },
    buffer_close_icon = "󰅖",
    modified_icon = "●",
    close_icon = "",
    left_trunc_marker = "",
    right_trunc_marker = "",
    --- name_formatter can be used to change the buffer's label in the bufferline.
    --- Please note some names can/will break the
    --- bufferline so use this at your discretion knowing that it has
    --- some limitations that will *NOT* be fixed.
    name_formatter = function(buf) -- buf contains:
      -- name                | str        | the basename of the active file
      -- path                | str        | the full path of the active file
      -- bufnr (buffer only) | int        | the number of the active buffer
      -- buffers (tabs only) | table(int) | the numbers of the buffers in the tab
      -- tabnr (tabs only)   | int        | the "handle" of the tab, can be converted to its ordinal number using: `vim.api.nvim_tabpage_get_number(buf.tabnr)`
    end,
    max_name_length = 18,
    max_prefix_length = 15, -- prefix used when a buffer is de-duplicated
    truncate_names = true, -- whether or not tab names should be truncated
    tab_size = 18,
    diagnostics = "nvim_lsp",
    diagnostics_update_in_insert = true,
    -- The diagnostics indicator can be set to nil to keep the buffer name highlight but delete the highlighting
    diagnostics_indicator = function(count, level, diagnostics_dict, context)
      return "(" .. count .. ")"
    end,
    -- NOTE: this will be called a lot so don't do any heavy processing here
    custom_filter = function(buf_number, buf_numbers)
      -- filter out filetypes you don't want to see
      if vim.bo[buf_number].filetype == "fern" then
        return false
      end

      if vim.bo.filetype == "qf" then
        return false
      end
      -- filter out by buffer name
      if vim.fn.bufname(buf_number) ~= "" then
        return true
      end
      return true
    end,
    offsets = {
      -- {
      --     filetype = "NvimTree",
      --     text = "File Explorer" | function ,
      --     text_align = "left" | "center" | "right"
      --     separator = true
      -- }
    },
    color_icons = true, -- whether or not to add the filetype icon highlights
    get_element_icon = function(element)
      -- element consists of {filetype: string, path: string, extension: string, directory: string}
      -- This can be used to change how bufferline fetches the icon
      -- for an element e.g. a buffer or a tab.
      -- e.g.
    end,
    show_buffer_icons = true, -- disable filetype icons for buffers
    show_buffer_close_icons = true,
    show_close_icon = true,
    show_tab_indicators = true,
    show_duplicate_prefix = true, -- whether to show duplicate buffer prefix
    persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
    move_wraps_at_ends = false, -- whether or not the move command "wraps" at the first or last position
    -- can also be a table containing 2 custom separators
    -- [focused and unfocused]. eg: { '|', '|' }
    separator_style = "slant",
    enforce_regular_tabs = false,
    always_show_bufferline = false,
    hover = {
      enabled = true,
      delay = 200,
      reveal = { "close" },
    },
    sort_by = "insert_after_current",
  },
}

local close_all_buffer_except_current = function()
  vim.api.nvim_command "BufferLineCloseLeft"
  vim.api.nvim_command "BufferLineCloseRight"
end

local map = vim.api.nvim_set_keymap
for i = 1, 9 do
  map(
    "n",
    ("\\%s"):format(i),
    (":lua require('bufferline').go_to_buffer(%s, true)<CR>"):format(i),
    { silent = true, desc = "Go to buffer #" .. i }
  )
  map(
    "n",
    ("\\$"):format(i),
    (":lua require('bufferline').go_to_buffer(-1, true)<CR>"):format(i),
    { silent = true, desc = "Go to last buffer #" .. i }
  )
end

vim.keymap.set("n", "\\cl", function()
  close_all_buffer_except_current()
end, { silent = true })
-- move to leftmost window
-- https://superuser.com/questions/231144/how-can-i-close-the-leftmost-window-in-vim
map("n", "\\ml", ":1wincmd w<CR>", { silent = true })
map("n", "\\n", ":BufferLineCycleNext<CR>", { silent = true })
map("n", "\\p", ":BufferLineCyclePrev<CR>", { silent = true })
