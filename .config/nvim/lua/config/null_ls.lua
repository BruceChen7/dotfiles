local nls = require "null-ls"

local fmt = nls.builtins.formatting

-- register any number of sources simultaneously
local sources = {
  fmt.gofmt,
  fmt.goimports,
  fmt.stylua,

  fmt.rustfmt.with {
    extra_args = { "--edition=2021" },
  },
  fmt.zigfmt,
  fmt.trim_whitespace.with {
    filetypes = { "go", "rust", "zig", "markdown", "lua" },
  },

  fmt.trim_newlines.with {
    filetypes = { "go", "rust", "zig", "markdown", "lua" },
  },
}

-- Configuring null-ls
nls.setup {
  debug = false,
  log = {
    enable = false,
  },
  sources = sources,
}
