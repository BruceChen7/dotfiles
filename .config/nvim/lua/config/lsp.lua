local rounded = { border = "rounded" }
vim.diagnostic.config { float = rounded }
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, rounded)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, rounded)
require("lsp-setup").setup {
  inlay_hints = {
    enabled = true,
  },
  servers = {
    gopls = {
      settings = {
        gopls = {
          gofumpt = true,
          -- staticcheck = true,
          usePlaceholders = true,
          codelenses = {
            gc_details = true,
          },
          analyses = {
            -- find structs that would use less memory if their fields were sorted
            fieldalignment = true,
            unusedparams = true,
            shadow = true,
            unusedwrite = true, -- checks for unused writes, an instances of writes to struct fields and arrays that are never read
            nonewvars = true,
            fillreturns = true,
            nilness = true, -- check for redundant or impossible nil comparisons
          },
          staticcheck = true,
          hints = {
            rangeVariableTypes = true,
            parameterNames = true,
            constantValues = true,
            assignVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            functionTypeParameters = true,
          },
          usePlaceholders = false,
          gofumpt = true,
          semanticTokens = true,
        },
      },
    },
  },
}
