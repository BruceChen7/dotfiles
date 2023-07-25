local rounded = { border = "rounded" }
vim.diagnostic.config { float = rounded }
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, rounded)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, rounded)
local opts = { noremap = true, silent = true }
vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)
vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)
vim.keymap.set("n", "gs", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", opts)
vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts)
vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

local function contains(table_name, value)
  for _, v in pairs(table_name) do
    if v == value then
      return true
    end
  end
end

vim.api.nvim_create_autocmd({ 'InsertEnter' }, {
  callback = function()
    -- if filetype is go or rust or lua
    -- pyright is not support textDocument/inlayHint
    -- if vim.bo.filetype is go or rust or lua
    -- thena vim.lsp.inlay_hint(0, true)
    local lang = {
      "go",
      "rust",
      "lua",
      "zig",
    }
    local filetype = vim.bo.filetype
    if contains(lang, filetype) then
      vim.lsp.inlay_hint(0, true)
    end
  end,
})
vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
  callback = function()
    local lang = {
      "go",
      "rust",
      "lua",
      "zig",
    }
    if contains(lang, vim.bo.filetype) then
      vim.lsp.inlay_hint(0, false)
    end
  end,
})

require("lsp-setup").setup {
  default_mappings = false,
  --  manually set the inlay hints
  inlay_hints = {
    enabled = false,
  },
  on_attach = function(client, bufnr)
    local filetype = vim.bo.filetype
    local format = false
    if filetype == "go" or "rust" or "python" or "lua" or "zig" then
      format = true
    end
    if format then
      -- require("lsp-setup.utils").format_on_save(client)
    end
    require("lsp_signature").on_attach({}, bufnr)
  end,
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
    pylsp = {},
    -- pylsp = {
    --   settings = {
    --     pylsp = {
    --       -- PylspInstall python-lsp-black
    --       -- PylspInstall pyls-isort
    --       configurationSources = { "flake8" },
    --       plugins = {
    --         pycodestyle = {
    --           enabled = true,
    --         },
    --         mccabe = {
    --           enabled = false,
    --         },
    --         pyflakes = {
    --           enabled = true,
    --         },
    --         flake8 = {
    --           enabled = true,
    --         },
    --         black = {
    --           enabled = false,
    --         },
    --       },
    --     },
    --   },
    -- },
    pyright = {},
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
          usePlaceholders = false,
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
