---- stevearc/aerial.nvim
local update_delay = 500

require("aerial").setup {
  backends = { "lsp", "treesitter", "markdown" },
  close_behavior = "global",
  default_direction = "right",
  disable_max_lines = 3000,
  filter_kind = {
    "Class",
    "Constructor",
    "Enum",
    "Function",
    "Interface",
    "Module",
    "Method",
    "Struct",
    "Type",
  },
  highlight_on_hover = true,
  ignore = { filetypes = { "gomod" } },
  update_events = "TextChanged,InsertLeave",
  lsp = {
    update_when_errors = true,
    diagnostics_trigger_update = true,
    update_delay = update_delay,
  },
  treesitter = {
    update_delay = update_delay,
  },
  markdown = {
    update_delay = update_delay,
  },
  layout = {
    min_width = 30,
    placement_editor_edge = true,
    default_direction = "right",
  },
  on_attach = function(bufnr)
    -- Toggle the aerial window with <leader>a
    vim.api.nvim_buf_set_keymap(bufnr, "n", ",a", "<cmd>AerialToggle!<CR>", {})
    -- Jump forwards/backwards with '{' and '}'
    vim.api.nvim_buf_set_keymap(bufnr, "n", "{", "<cmd>AerialPrev<CR>", {})
    vim.api.nvim_buf_set_keymap(bufnr, "n", "}", "<cmd>AerialNext<CR>", {})
    -- Jump up the tree with '[[' or ']]'
    vim.api.nvim_buf_set_keymap(bufnr, "n", "[[", "<cmd>AerialPrevUp<CR>", {})
    vim.api.nvim_buf_set_keymap(bufnr, "n", "]]", "<cmd>AerialNextUp<CR>", {})
  end,
}

local treesitter_langs = require "aerial.backends.treesitter.language_kind_map"

-- SEE: queries/rescript/aerial.scm
treesitter_langs.rescript = {
  ["function"] = "Function",
  module_declaration = "Module",
  type_declaration = "Type",
  type_annotation = "Interface",
  external_declaration = "Interface",
}
