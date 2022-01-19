local nls = require('null-ls')

local fmt = nls.builtins.formatting

-- register any number of sources simultaneously
local sources = {
    -- null_ls.builtins.formatting.prettier,
    -- null_ls.builtins.diagnostics.write_good,
    -- null_ls.builtins.code_actions.gitsigns,
    fmt.gofmt,
    fmt.goimports,
    fmt.rustfmt,
    fmt.zigfmt,
    fmt.trim_whitespace.with(
        {
            filetypes = {"go", "rust", "zig", "markdown", "lua"},
        }
    ),


    fmt.trim_newlines.with(
        {
            filetypes = {"go", "rust", "zig", "markdown", "lua"},
        }
    ),
}

-- Configuring null-ls
nls.setup({
    debug = false,
    log = {
        enable =  false,
    },
    sources = sources,
})
