require("mini.cursorword").setup { delay = 0 }
require("mini.surround").setup {
  mappings = {
    add = ",sa",
    delete = ",sd",
    find = ",sf",
    replace = ",sr",
    highlight = ",sh",
    update_n_lines = ",su",
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

local miniclue = require "mini.clue"
miniclue.setup {
  window = {
    delay = 100,
    -- config = {
    --   border = "dobule",
    -- },
  },
  triggers = {
    { mode = "n", keys = "<space>" },
    { mode = "x", keys = "<space>" },
    { mode = "n", keys = ";" },
    { mode = "x", keys = ";" },
    { mode = "n", keys = "," },
    { mode = "x", keys = "," },
    { mode = "n", keys = ",d", desc = "+Git Diff" },
    { mode = "n", keys = "g" },
  },
  clues = {
    {
      mode = "n",
      keys = ",dh",
      postkeys = ",d",
      desc = "+Git Diff",
    },
  },
}
