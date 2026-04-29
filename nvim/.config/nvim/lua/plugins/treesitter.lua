local pack = require "core.pack"
local gh = pack.github

return {
  name = "treesitter",
  specs = {
    { src = gh "nvim-treesitter/nvim-treesitter", version = "main" },
    { src = gh "ravsii/tree-sitter-d2" },
    { src = gh "sustech-data/wildfire.nvim" },
    { src = gh "abecodes/tabout.nvim" },
    { src = gh "meznaric/key-analyzer.nvim" },
  },
  setup = function()
    pack.setup_config("nvim-treesitter", "config/text_obj")

    pack.safe_call("wildfire", function()
      pack.packadd "wildfire.nvim"
      require("wildfire").setup {
        keymaps = {
          init_selection = "<CR>",
          node_incremental = "<CR>",
          node_decremental = "<BS>",
        },
      }
    end)

    pack.setup_config("tabout.nvim", "config/tabout")

    pack.safe_call("key-analyzer", function()
      pack.packadd "key-analyzer.nvim"
      require("key-analyzer").setup {}
    end)
  end,
}
