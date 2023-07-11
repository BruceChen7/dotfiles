local util = require "formatter.util"
require("formatter").setup {
  logging = false,
  filetype = {
    lua = {
      require("formatter.filetypes.lua").stylua,
      function()
        return {
          exe = "stylua",
          args = {
            "--search-parent-directories",
            "--stdin-filepath",
            util.escape_path(util.get_current_buffer_file_path()),
            "--",
            "-",
          },
          stdin = true,
        }
      end,
    },
    c = {
      require("formatter.filetypes.c").clangformat,
    },

    markdown = { require("formatter.filetypes.markdown").prettier },
    rust = { require("formatter.filetypes.rust").rustfmt },
    json = { require("formatter.filetypes.json").prettier },

    go = {
      require("formatter.filetypes.go").goimports,
    },
    zig = {
      require("formatter.filetypes.zig").zigfmt,
    },

    ["*"] = {
      -- "formatter.filetypes.any" defines default configurations for any
      -- filetype
      require("formatter.filetypes.any").remove_trailing_whitespace,
    },
  },
}

vim.cmd [[
augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
]]
