local has_lsp, lspconfig = pcall(require, "lspconfig")
if not has_lsp then
  return
end

local nvim_lsp = require "lspconfig"
-- local lspkind = require "lspkind"
-- lspkind.init()

-- vim.lsp.set_log_level "trace"
-- require("vim.lsp.log").set_format_func(vim.inspect)
--
local signature_config = {
  log_path = vim.fn.expand "$HOME" .. "/tmp/sig.log",
  debug = false,
  hint_enable = true,
  handler_opts = { border = "double", floating_window = true },
  max_width = 80,
}

require("lsp_signature").setup(signature_config)

vim.keymap.set("n", "<space>e", vim.diagnostic.open_float)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<space>d", vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set("n", "<space>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "<space>f", function()
      vim.lsp.buf.format { async = true }
    end, opts)
    -- vim.keymap.set("n", "gd", "<cmd> lua jump_to_definition()<CR>", opts)
  end,
})

function jump_to_definition()
  local params = vim.lsp.util.make_position_params()
  vim.lsp.buf_request(0, "textDocument/definition", params, function(err, result)
    if err then
      print("Error when jumping to definition: " .. err)
      return
    end

    if result == nil or #result == 0 then
      return
    end

    local uri = result[1].uri or result[1].targetUri
    local buffer_number = vim.uri_to_bufnr(uri)
    local jump_buf_name = vim.fn.bufname(buffer_number)
    if string.sub(jump_buf_name, 1, 1) ~= "/" then
      -- print "relative direcotry"
      jump_buf_name = vim.fn.getcwd() .. "/" .. jump_buf_name
    end
    local found_buffer = false
    local jump_win = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      -- print("win " .. win)
      local buf = vim.api.nvim_win_get_buf(win)
      -- print("buf name " .. vim.api.nvim_buf_get_name(buf))
      bufname = vim.api.nvim_buf_get_name(buf)
      if bufname == jump_buf_name then
        found_buffer = true
        jump_win = win
        break
      end
    end

    if found_buffer then
      vim.api.nvim_set_current_win(jump_win)
      local range = result[1].range or result[1].targetRange
      -- The target buffer is already open, so just jump to the definition
      -- vim.fn.cursor(range.start.line + 1, range.start.character + 1)
      -- https://stackoverflow.com/questions/19195160/push-a-location-to-the-jumplist
      vim.cmd("normal " .. range.start.line + 1 .. "G" .. range.start.character + 1 .. "|")
    else
      -- The target buffer is not open, so open it in a new split and jump to the definition
      vim.cmd "vsplit"
      vim.cmd("edit " .. jump_buf_name)
      local range = result[1].range or result[1].targetRange
      -- vim.fn.cursor(range.start.line + 1, range.start.character + 1)
      vim.api.nvim_win_set_cursor(0, { range.start.line + 1, range.start.character + 1 })
    end
  end)
end

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- https://github.com/golang/go/issues/54531
  -- if client.name == "gopls" and not client.server_capabilities.semanticTokensProvider then
  --   local semantic = client.config.capabilities.textDocument.semanticTokens
  --   client.server_capabilities.semanticTokensProvider = {
  --     full = true,
  --     legend = {
  --       tokenModifiers = semantic.tokenModifiers,
  --       tokenTypes = semantic.tokenTypes,
  --     },
  --     range = true,
  --   }
  -- end

  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end
  -- https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Avoiding-LSP-formatting-conflictsclient
  client.server_capabilities.document_formatting = false
  client.server_capabilities.document_range_formatting = false

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local capabilities = vim.lsp.protocol.make_client_capabilities()
-- capabilities = require("cmp_nvim_lsp").make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
capabilities.textDocument.completion.completionItem.preselectSupport = true
capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true

-- for folding
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
nvim_lsp["clangd"].setup {
  capabilities = capabilities,
  on_attach = on_attach,
  init_options = {
    onlyAnalyzeProjectsWithOpenFiles = true,
    suggestFromUnimportedLibraries = false,
    closingLabels = true,
  },
  handlers = {
    ["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
      -- Disable inline diagnostics
      virtual_text = false,
    }),
  },
  cmd = {
    "clangd",
    "--background-index",
    "--pch-storage=memory",
    "--completion-style=detailed",
    "-j=8",
    "--clang-tidy",
  },
  filetypes = { "c", "cpp" },
}

nvim_lsp["gopls"].setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {
    "gopls",
    -- "serve",
    -- "--debug=localhost:6060",
    -- "-profile.cpu=/Users/ming.chen/vim.txt",
  },
  autostart = true,
  settings = {
    gopls = {
      -- experimentalPostfixCompletions = true,
      completeUnimported = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
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
      codelenses = {
        test = true,
        gc_details = true, -- Toggle the calculation of gc annotations
        generate = true, -- Runs go generate for a given directory
        regenerate_cgo = true, -- Regenerates cgo definitions
        tidy = true, -- Runs go mod tidy for a module
        upgrade_dependency = true, -- Upgrades a dependency in the go.mod file for a module
        vendor = true, -- Runs go mod vendor for a module
      },
      -- enables placeholders for function parameters or struct fields in completion responses
      usePlaceholders = false,
      gofumpt = true,
      semanticTokens = true,
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
}

local servers = { "pyright", "zls" }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

-- use rust-tools to
require("rust-tools").setup {
  tools = {
    inlay_hints = {
      only_current_line = false,
      show_parameter_hints = true,
      parameter_hints_prefix = "<- ",
      -- prefix for all the other hints (type, chaining)
      -- default: "=>"
      other_hints_prefix = "=> ",
      highlight = "Comment",
      -- https://github.com/lvimuser/lsp-inlayhints.nvim#configuration
      auto = false,
    },
    hover_actions = {
      auto_focus = false,
    },
  },
  server = {
    on_attach = on_attach,
    capabilities = capabilities,
    standalone = false,
    -- cmd = rust_server:get_default_options().cmd,
    settings = {
      ["rust-analyzer"] = {
        assist = {
          importPrefix = "by_self",
          importGranularity = "module",
        },
        diagnostics = {
          -- https://github.com/rust-analyzer/rust-analyzer/issues/6835
          disabled = { "unresolved-macro-call" },
          enableExperimental = true,
        },
        completion = {
          autoimport = {
            enable = true,
          },
          postfix = {
            enable = true,
          },
        },
        cargo = {
          loadOutDirsFromCheck = true,
          autoreload = true,
          runBuildScripts = true,
        },
        procMacro = {
          enable = true,
        },
        lens = {
          enable = true,
          run = true,
          methodReferences = true,
          implementations = true,
        },
        hoverActions = {
          enable = true,
        },
        inlayHints = {
          chainingHintsSeparator = "‣ ",
          typeHintsSeparator = "‣ ",
          typeHints = true,
          auto = false,
        },
        checkOnSave = {
          enable = true,
          -- https://github.com/rust-analyzer/rust-analyzer/issues/9768
          -- command = 'clippy',
          allFeatures = true,
        },
      },
    },
  },
}
