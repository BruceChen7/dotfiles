local rounded = { border = "rounded" }
vim.diagnostic.config { float = rounded }
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, rounded)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, rounded)
require("lsp-setup").setup {
  inlay_hints = {
    enabled = true,
  },
  servers = {
    lua_ls = {
      settings = {
        Lua = {
          workspace = {
            checkThirdParty = false,
          },
          hint = {
            enable = false,
          },
          format = {
            enable = false,
          },
        },
      },
    },
    rust_analyzer = {
      settings = {
        ["rust-analyzer"] = {
          inlayHints = {
            bindingModeHints = {
              enable = false,
            },
            chainingHints = {
              enable = true,
            },
            closingBraceHints = {
              enable = true,
              minLines = 25,
            },
            closureReturnTypeHints = {
              enable = "never",
            },
            lifetimeElisionHints = {
              enable = "never",
              useParameterNames = false,
            },
            maxLength = 25,
            parameterHints = {
              enable = true,
            },
            reborrowHints = {
              enable = "never",
            },
            renderColons = true,
            typeHints = {
              enable = true,
              hideClosureInitialization = false,
              hideNamedConstructor = false,
            },
          },
        },
      },
    },
    zls = {
      settings = {
        zls = {
          enable_inlay_hints = true,
          inlay_hints_show_builtin = true,
          inlay_hints_exclude_single_argument = true,
          inlay_hints_hide_redundant_param_names = true,
          inlay_hints_hide_redundant_param_names_last_token = true,
        },
      },
    },
    yamlls = {
      settings = {
        yaml = {
          keyOrdering = false,
        },
      },
    },
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
          semanticTokens = true,
        },
      },
    },
  },
}
