require("cokeline").setup {
  -- Only show the bufferline when there are at least this many visible buffers.
  -- default: `1`.
  show_if_buffers_are_at_least = 1,
  buffers = {
    -- A function to filter out unwanted buffers. Takes a buffer table as a
    -- parameter (see the following section for more infos) and has to return
    -- either `true` or `false`.
    -- default: `false`.
    filter_valid = function(buffer)
      return true
    end,

    filter_visible = function(buffer)
      return true
    end,
  },

  mappings = {
    cycle_prev_next = true,
  },
}

local map = vim.api.nvim_set_keymap
for i = 1, 9 do
  map("n", ("\\%s"):format(i), ("<Plug>(cokeline-focus-%s)"):format(i), { silent = true })
  map("n", ("<Leader>%s"):format(i), ("<Plug>(cokeline-switch-%s)"):format(i), { silent = true })
end
