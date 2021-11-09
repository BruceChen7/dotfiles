local U = require("util")
local nvim_lsp = require('lspconfig')

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
	local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
	local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

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
	U.map('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
	U.map('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
	U.map('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
	U.map('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)

end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local capabilities = vim.lsp.protocol.make_client_capabilities()
local servers = {'pyright', 'gopls', 'clangd', 'rust_analyzer'}
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
for _, lsp in ipairs(servers) do
	nvim_lsp[lsp].setup {
		on_attach = on_attach,
		capabilities = capabilities,
	}
end

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- luasnip setup
local luasnip = require 'luasnip'

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
		['<C-j>'] = cmp.mapping.select_next_item(),
		['<C-n>'] = cmp.mapping.select_next_item(),
		['<C-d>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		['<C-Space>'] = cmp.mapping.complete(),
		['<C-e>'] = cmp.mapping.close(),
		['<CR>'] = cmp.mapping.confirm {
			behavior = cmp.ConfirmBehavior.Replace,
			select = true,
		},
		['<Tab>'] = function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end,
		['<S-Tab>'] = function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end,
	},
	sources = {
		{ name = 'nvim_lsp' },
		{ name = 'luasnip' },
	},
}
