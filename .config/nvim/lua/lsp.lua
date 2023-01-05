local has_lsp, lspconfig = pcall(require, "lspconfig")
if not has_lsp then
  return
end

local u = require "util"
local nvim_lsp = require "lspconfig"
local lspkind = require "lspkind"
lspkind.init()

function set_key()
  -- Mappings.
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  u.map("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  u.map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  -- u.map('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  u.map("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
  u.map("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
  u.map("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
  u.map("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
  u.map("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  u.map("n", "<space>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
  u.map("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  u.map("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
  u.map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  u.map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
  u.map("n", "<space>d", "<cmd>lua vim.diagnostic.setloclist()<CR>", opts)
  u.map("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  u.map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  u.map("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
end

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end
  -- https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Avoiding-LSP-formatting-conflictsclient
  client.server_capabilities.document_formatting = false
  client.server_capabilities.document_range_formatting = false

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
  if vim.loop.os_uname().sysname == "Linux" then
    set_key()
  end

  -- Mappings.
  require("lsp_signature").on_attach({
    bind = true,
    handler_opts = {
      border = "double",
      floating_window = true,
    },
  }, bufnr)
end

-- if not set, macos not working
if vim.loop.os_uname().sysname ~= "Linux" then
  set_key()
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- local capabilities = vim.lsp.protocol.make_client_capabilities()
-- local servers = { "pyright", "gopls", "clangd", "rust_analyzer", "zls" }
local servers = { "pyright", "gopls", "zls" }
capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
capabilities.textDocument.completion.completionItem.preselectSupport = true
-- for folding
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

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

for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
      gopls = {
        experimentalPostfixCompletions = true,
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
        gofumpt = true,
      },
    },
    flags = {
      debounce_text_changes = 150,
    },
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
      auto = true,
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

-- luasnip setup
local luasnip = require "luasnip"

-- Set completeopt to have a better completion experience
-- " :help completeopt
-- " menuone: popup even when there's only one match
-- " noinsert: Do not insert text until a selection is made
-- " noselect: Do not select, force user to select one from the menu
vim.o.completeopt = "menuone,noselect"

-- nvim-cmp setup
local cmp = require "cmp"

--
function select_next_item(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  elseif luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
  else
    fallback()
  end
end

function select_prev_item(fallback)
  if cmp.visible() then
    cmp.select_prev_item()
  elseif luasnip.jumpable(-1) then
    luasnip.jump(-1)
  else
    fallback()
  end
end

cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = {
    -- ["<C-p>"] = select_prev_item,
    ["<C-k>"] = select_prev_item,
    ["<C-j>"] = select_next_item,
    -- ["<C-n>"] = select_next_item,
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<M-CR>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.close(),
    ["<CR>"] = cmp.mapping(
      cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Insert,
        select = true,
      },
      { "i", "c" }
    ),
  },
  experimental = {
    ghost_text = true,
    native_menu = false,
  },
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
    { name = "nvim_lua" }, -- with vim.api complete
    {
      name = "buffer",
      keyword_length = 3,
      option = {
        get_bufnrs = function()
          return vim.api.nvim_list_bufs()
        end,
      },
    },
    { name = "crates" },
    -- { name = "tags" },
    -- { name = "rg" },
  },
  sorting = {
    -- TODO: Would be cool to add stuff like "See variable names before method names" in rust, or something like that.
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.score,

      -- copied from cmp-under, but I don't think I need the plugin for this.
      -- I might add some more of my own.
      function(entry1, entry2)
        local _, entry1_under = entry1.completion_item.label:find "^_+"
        local _, entry2_under = entry2.completion_item.label:find "^_+"
        entry1_under = entry1_under or 0
        entry2_under = entry2_under or 0
        if entry1_under > entry2_under then
          return false
        elseif entry1_under < entry2_under then
          return true
        end
      end,

      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },

  -- formatting = {
  --   -- Youtube: How to set up nice formatting for your sources.
  --   format = lspkind.cmp_format {
  --     with_text = true,
  --     menu = {
  --       buffer = "[buf]",
  --       nvim_lsp = "[LSP]",
  --       nvim_lua = "[api]",
  --       path = "[path]",
  --       luasnip = "[snip]",
  --       -- gh_issues = "[issues]",
  --       -- tn = "[TabNine]",
  --     },
  --   },
  -- },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      local lspkind_icons = {
        Text = "",
        Method = " ",
        Function = "",
        Constructor = " ",
        Field = " ",
        Variable = " ",
        Class = "",
        Interface = "",
        Module = "硫",
        Property = "",
        Unit = " ",
        Value = "",
        Enum = " ",
        Keyword = "ﱃ",
        Snippet = " ",
        Color = " ",
        File = " ",
        Reference = "Ꮢ",
        Folder = " ",
        EnumMember = " ",
        Constant = " ",
        Struct = " ",
        Event = "",
        Operator = "",
        TypeParameter = " ",
      }
      local meta_type = vim_item.kind
      -- load lspkind icons
      vim_item.kind = lspkind_icons[vim_item.kind] .. ""

      vim_item.menu = ({
        buffer = " Buffer",
        nvim_lsp = meta_type,
        path = " Path",
        luasnip = " LuaSnip",
        tags = " Tags",
        -- rg = "Rg",
      })[entry.source.name]

      return vim_item
    end,
  },
}

-- insert `(` after select function or method item
local cmp_autopairs = require "nvim-autopairs.completion.cmp"
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done { map_char = { tex = "" } })

-- https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Avoiding-LSP-formatting-conflictsclient
vim.cmd [[
augroup FormatGroup
    au!
    autocmd BufWritePre *.go lua vim.lsp.buf.format()
    autocmd BufWritePre *.md lua vim.lsp.buf.format()
    autocmd BufWritePre *.rs lua vim.lsp.buf.format()
    autocmd BufWritePre *.zig lua vim.lsp.buf.format()
    autocmd BufWritePre *.lua lua vim.lsp.buf.format()
augroup END
]]
