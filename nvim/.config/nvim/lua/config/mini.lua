require("mini.cursorword").setup { delay = 0 }
require("mini.surround").setup {
  mappings = {
    add = "<Space>sa",
    delete = "<Space>sd",
    find = "<Space>sf",
    replace = "<Space>sr",
    highlight = "<Space>sh",
    update_n_lines = "<Space>su",
  },
}
require("mini.trailspace").setup {}

require("mini.pairs").setup {}

-- https://github.com/oncomouse/dotfiles/blob/2a58fa952eacb751ff24361efd81308716a759c1/conf/vim/lua/dotfiles/plugins/mini-nvim.lua#L104
require("mini.ai").setup {
  custom_text_objects = {
    e = function()
      local from = { line = 1, col = 1 }
      local last_line_length = #vim.fn.getline "$"
      local to = {
        line = vim.fn.line "$",
        col = last_line_length == 0 and 1 or last_line_length,
      }
      return { from = from, to = to, vis_mode = "V" }
    end,
  },
}
