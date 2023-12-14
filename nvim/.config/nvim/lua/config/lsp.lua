local rounded = { border = "rounded" }
vim.diagnostic.config { float = rounded }
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, rounded)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, rounded)

-- https://www.reddit.com/r/neovim/comments/17yrtt5/seeking_guidance_for_improving_nvimcmp/
vim.lsp.util.stylize_markdown = function(bufnr, contents, opts)
  contents = vim.lsp.util._normalize_markdown(contents, {
    width = vim.lsp.util._make_floating_popup_size(contents, opts),
  })
  vim.bo[bufnr].filetype = "markdown"
  vim.treesitter.start(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)

  return contents
end

local function find_definition()
  -- 如果当前的文件是c, cpp, h文件
  local file_type = vim.bo.filetype
  if file_type == "c" or file_type == "cpp" or file_type == "h" then
    -- get current cursor word
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    -- print("before row and new row", row, col)
    vim.cmd [[
      execute 'Telescope lsp_definitions'
    ]]
    -- wait 10 ms
    vim.defer_fn(function()
      vim.cmd [[
        let word = expand("<cword>")
        silent execute 'Cscope find g ' . word
      ]]
      local next_row, next_col = unpack(vim.api.nvim_win_get_cursor(0))
      if next_row == row and next_col == col then
        vim.cmd [[
          let word = expand("<cword>")
          silent execute "Cstag " . word
        ]]
      end
    end, 10)
    return
  end
  vim.cmd [[
    execute 'Telescope lsp_definitions'
  ]]
end
vim.keymap.set("n", "gd", function()
  find_definition()
end, { noremap = true, silent = true, desc = "Find Definition" })
vim.keymap.set(
  "n",
  "gi",
  "<cmd>Telescope lsp_implementations<CR>",
  { noremap = true, silent = true, desc = "Find Implementation" }
)
vim.keymap.set(
  "n",
  "\\gs",
  "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>",
  { noremap = true, silent = true, desc = "Find Symbols" }
)

vim.keymap.set(
  "n",
  "gs",
  "<cmd>Telescope lsp_document_symbols<CR>",
  { noremap = true, silent = true, desc = "find Document Symbols" }
)

vim.keymap.set(
  "n",
  "gr",
  "<cmd>Telescope lsp_references<CR>",
  { noremap = true, silent = true, desc = "Find References" }
)
-- vim.keymap.set("n", "K", vim.lsp.buf.hover, { noremap = true, silent = true, desc = "Hover" })
vim.keymap.set("n", "\\gr", "<cmd>lua vim.lsp.buf.rename()<CR>", { noremap = true, silent = true, desc = "Rename" })

local function contains(table_name, value)
  for _, v in pairs(table_name) do
    if v == value then
      return true
    end
  end
end

local versionThan9 = vim.version().minor > 9
vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    -- if filetype is go or rust or lua
    -- pyright is not support textDocument/inlayHint
    -- if vim.bo.filetype is go or rust or lua
    -- thena vim.lsp.inlay_hint.enable(0, true)
    local lang = {
      "go",
      "rust",
      "lua",
      "zig",
      "typescript",
    }

    if versionThan9 then
      local filetype = vim.bo.filetype
      if contains(lang, filetype) then
        vim.lsp.inlay_hint.enable(0, true)
      end
    end
  end,
})
vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    local lang = {
      "go",
      "rust",
      "lua",
      "zig",
      "typescript",
    }
    if versionThan9 then
      if contains(lang, vim.bo.filetype) then
        vim.lsp.inlay_hint.enable(0, false)
      end
    end
  end,
})
-- https://github.com/kevinhwang91/nvim-ufo
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}
require("lsp-setup").setup {
  default_mappings = false,
  capabilities = capabilities,
  --  manually set the inlay hints
  inlay_hints = {
    enabled = false,
  },
  on_attach = function(client, bufnr)
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
    tsserver = {
      settings = {
        typescript = {
          inlayHints = {
            includeInlayParameterNameHints = "all",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = true,
            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
      },
    },
    clangd = {
      cmd = {
        "clangd",
        "--background-index",
        "--completion-style=detailed",
        "-j=8",
        "--clang-tidy",
      },
      filetypes = { "c", "cpp", "objc", "objcpp" },
    },
    tailwindcss = {
      cmd = {
        "tailwindcss-language-server",
        "--stdio",
      },
    },
    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#svelte
    svelte = {
      cmd = {
        "svelteserver",
        "--stdio",
      },
    },
    pyright = {},
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
      cmd = {
        "gopls",
        -- "--debug=localhost:6060",
        -- "-profile.cpu=/Users/ming.chen/gopls.out",
        -- "-mode=stdi",
        -- "-logfile=/Users/ming.chen/gopls.log",
        -- "-rpc.trace",
      },
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
          -- semanticTokens = true,
        },
      },
    },
  },
}

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.md",
  callback = function()
    MiniTrailspace.trim()
  end,
})
