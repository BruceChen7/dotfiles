-- luasnip setup
--
local lspkind = require "lspkind"
lspkind.init()
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
local function select_next_item(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  elseif luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
  else
    fallback()
  end
end

local function select_prev_item(fallback)
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
    ghost_text = false,
    native_menu = false,
  },
  sources = {
    { name = "nvim_lsp", priority = 1000 },
    { name = "luasnip", priority = 900 },
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
    { name = "codeium", priority = 800 },
    { name = "crates" },
    { name = "cmp_tabnine", priority = 700 },
  },
  matching = {
    disallow_fuzzy_matching = true,
    disallow_fullfuzzy_matching = true,
    disallow_partial_fuzzy_matching = false,
    disallow_partial_matching = false,
    disallow_prefix_unmatching = true,
  },
  sorting = {
    comparators = {
      cmp.config.compare.locality,
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.recently_used,
      cmp.config.compare.score,
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
        Method = " ",
        Function = "",
        Constructor = " ",
        Field = " ",
        Variable = " ",
        Class = "",
        Interface = "󰎕",
        Module = "󰓏",
        Property = "󰏣",
        Unit = " ",
        Value = "󰎈",
        Enum = " ",
        Keyword = "󰝅",
        Snippet = " ",
        Color = "󰏘 ",
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
        TabNine = " ",
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