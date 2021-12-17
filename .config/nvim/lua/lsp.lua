local has_lsp, lspconfig = pcall(require, "lspconfig")
if not has_lsp then
    return
end

local U = require("util")
local nvim_lsp = require('lspconfig')
local lspkind = require "lspkind"
lspkind.init()

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
    local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
    local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end
    -- https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Avoiding-LSP-formatting-conflictsclient
    client.resolved_capabilities.document_formatting = false
    client.resolved_capabilities.document_range_formatting = false

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local opts = { noremap=true, silent=true }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    U.map('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    U.map('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    U.map('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    U.map('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    U.map('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    U.map('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
    U.map('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    U.map('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    U.map('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    U.map('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    U.map('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
    U.map('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    U.map('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
    U.map('n', '<space>d', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
    U.map('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
    U.map('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    U.map('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)

    require "lsp_signature".on_attach({
        bind = true,
        handler_opts = {
            border = "double",
            floating_window = true,
        }
    }, bufnr)
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local capabilities = vim.lsp.protocol.make_client_capabilities()
local servers = {'pyright', 'gopls', 'clangd', 'rust_analyzer', 'zls'}
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
capabilities.textDocument.completion.completionItem.snippetSupport = true

for _, lsp in ipairs(servers) do
    nvim_lsp[lsp].setup {
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
            gopls = {
                experimentalPostfixCompletions = true,
                analyses = {
                    unusedparams = true,
                    shadow = true,
                },
                staticcheck = true,
                codelenses = {
                    test = true,
                }
            },
        },
        flags = {
            debounce_text_changes = 200,
        }
    }
end

-- luasnip setup
local luasnip = require 'luasnip'

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'


-- set goimport
-- https://www.getman.io/posts/programming-go-in-neovim/
function goimports(timeoutms)
    local context = { source = { organizeImports = true } }
    vim.validate { context = { context, "t", true } }

    local params = vim.lsp.util.make_range_params()
    params.context = context

    -- See the implementation of the textDocument/codeAction callback
    -- (lua/vim/lsp/handler.lua) for how to do this properly.
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, timeout_ms)
    if not result or next(result) == nil then return end
    local actions = result[1].result
    if not actions then return end
    local action = actions[1]

    -- textDocument/codeAction can return either Command[] or CodeAction[]. If it
    -- is a CodeAction, it can have either an edit, a command or both. Edits
    -- should be executed first.
    if action.edit or type(action.command) == "table" then
        if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit)
        end
        if type(action.command) == "table" then
            vim.lsp.buf.execute_command(action.command)
        end
    else
        vim.lsp.buf.execute_command(action)
    end
end

-- nvim-cmp setup
local cmp = require 'cmp'
cmp.setup {
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = {
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-k>'] = cmp.mapping.select_prev_item(),
        ['<C-j>'] = cmp.mapping.select_next_item(),
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<M-CR>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.close(),
        -- ['<CR>'] = cmp.mapping.confirm {
        --  behavior = cmp.ConfirmBehavior.Replace,
        --  select = true,
        -- },
        ["<CR>"] = cmp.mapping(
            cmp.mapping.confirm {
                behavior = cmp.ConfirmBehavior.Insert,
                select = true,
            },
            { "i", "c" }
        ),

        -- ['<Tab>'] = function(fallback)
        --  if cmp.visible() then
        --      cmp.select_next_item()
        --  elseif luasnip.expand_or_jumpable() then
        --      luasnip.expand_or_jump()
        --  else
        --      fallback()
        --  end
        -- end,
        -- ['<S-Tab>'] = function(fallback)
        --  if cmp.visible() then
        --      cmp.select_prev_item()
        --  elseif luasnip.jumpable(-1) then
        --      luasnip.jump(-1)
        --  else
        --      fallback()
        --  end
        -- end,
    },
    sources = {
        { name = "nvim_lsp" },
        { name = "path" },
        { name = "nvim_lua" },
        { name = "luasnip" },
        { name = "buffer", keyword_length = 3 },
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
        -- Youtube: How to set up nice formatting for your sources.
        format = lspkind.cmp_format {
            with_text = true,
            menu = {
                buffer = "[buf]",
                nvim_lsp = "[LSP]",
                nvim_lua = "[api]",
                path = "[path]",
                luasnip = "[snip]",
                -- gh_issues = "[issues]",
                -- tn = "[TabNine]",
            },
        },
    },

}

-- insert `(` after select function or method item
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
cmp.event:on( 'confirm_done', cmp_autopairs.on_confirm_done({  map_char = { tex = '' } }))

-- format code
-- " autocmd BufWritePre *.go lua goimports(1000)
-- " autocmd BufWritePre *.rust lua vim.lsp.buf.formatting()
-- format code
vim.cmd([[
augroup FormatGroup
    au!
    autocmd BufWritePre *.go lua vim.lsp.buf.formatting_seq_sync()
augroup END
]])
