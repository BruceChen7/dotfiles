-- Parsers must be installed manually via :TSInstall
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua
local tc = require "nvim-treesitter.configs"
tc.setup {
  highlight = {
    enable = true, -- false will disable the whole extension
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      -- init_selection = "gnn",
      init_selection = "<CR>",
      -- node_incremental = "grn",
      node_incremental = "<TAB>",
      scope_incremental = "<CR>",
      -- scope_incremental = "grc",
      -- node_decremental = "grm",
      node_decremental = "S-<TAB>",
    },
  },
  rainbow = {
    enable = true,
    -- disable = { "jsx", "cpp" }, list of languages you want to disable the plugin for
    extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    max_file_lines = nil, -- Do not enable for files with more than n lines, int
    -- colors = {}, -- table of hex strings
    -- termcolors = {} -- table of colour name strings
  },
  indent = {
    enable = true,
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["ii"] = "@parameter.inner",
        ["ai"] = "@parameter.outer",
        ["il"] = "@loop.inner",
        ["al"] = "@loop.outer",
        ["id"] = "@conditional.inner",
        ["ad"] = "@conditional.outer",
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]]"] = "@class.outer",
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]["] = "@class.outer",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[["] = "@class.outer",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[]"] = "@class.outer",
      },
    },
    lsp_interop = {
      enable = true,
      border = "none",
      -- press K can do the same
      peek_definition_code = {
        ["<leader>df"] = "@function.outer",
        ["<leader>dF"] = "@class.outer",
      },
    },
  },
}
