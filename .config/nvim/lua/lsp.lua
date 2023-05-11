local has_lsp, lspconfig = pcall(require, "lspconfig")
if not has_lsp then
  return
end

local u = require "util"
local nvim_lsp = require "lspconfig"
local lspkind = require "lspkind"
lspkind.init()

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
    -- vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
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
    -- u.map("n", "gpd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    -- u.map("n", "gsd", "<cmd> vsplit | lua vim.lsp.buf.definition()<CR>", opts)
    vim.keymap.set("n", "gd", "<cmd> lua jump_to_definition()<CR>", opts)
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
    -- print("uri.." .. uri)
    -- print("jump_buf_name.." .. jump_buf_name)
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
  if client.name == "gopls" and not client.server_capabilities.semanticTokensProvider then
    local semantic = client.config.capabilities.textDocument.semanticTokens
    client.server_capabilities.semanticTokensProvider = {
      full = true,
      legend = {
        tokenModifiers = semantic.tokenModifiers,
        tokenTypes = semantic.tokenTypes,
      },
      range = true,
    }
  end

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
-- local capabilities = vim.lsp.protocol.make_client_capabilities()
-- local servers = { "pyright", "gopls", "clangd", "rust_analyzer", "zls" }
local servers = { "pyright", "zls" }
capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
capabilities.textDocument.completion.completionItem.preselectSupport = true

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
      { "i" }
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
    { name = "codeium" },
    { name = "crates" },
    { name = "cmp_tabnine" },
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
        Codeium = "",
        TabNine = "",
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
        codeium = " Codeium",
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
format_group = vim.api.nvim_create_augroup("FormatGroup", { clear = true })
format_file_type = { "go", "zig", "md", "rs", "lua", "py" }
for _, v in ipairs(format_file_type) do
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    pattern = string.format("*.%s", v),
    group = format_group,
    callback = function()
      vim.lsp.buf.format()
    end,
  })
end

vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
vim.api.nvim_create_autocmd("LspAttach", {
  group = "LspAttach_inlayhints",
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end

    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    require("lsp-inlayhints").on_attach(client, bufnr)
  end,
})
