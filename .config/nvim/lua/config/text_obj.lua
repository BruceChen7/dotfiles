-- Parsers must be installed manually via :TSInstall
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua
local tc = require "nvim-treesitter.configs"
tc.setup {
  ensure_installed = {
    "c",
    "cpp",
    "lua",
    "rust",
    "python",
    "make",
    "cmake",
    "bash",
    "markdown",
    "toml",
    "vim",
    "yaml",
    "go",
  },
  highlight = {
    enable = false,
    additional_vim_regex_highlighting = false,
    disable = function(lang, bufnr) -- Disable in large C++ buffers
      return lang == ("cpp" or lang == "go") and api.nvim_buf_line_count(bufnr) > 20000
    end,
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      node_incremental = "+",
      scope_incremental = "<CR>",
      node_decremental = "-",
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
    -- performance killer
    enable = false,
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
