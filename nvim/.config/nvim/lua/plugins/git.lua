local pack = require "core.pack"
local gh = pack.github

return {
  name = "git",
  specs = {
    { src = gh "lewis6991/gitsigns.nvim" },
    { src = gh "tpope/vim-fugitive" },
    { src = gh "sindrets/diffview.nvim" },
    { src = gh "TimUntersberger/neogit" },
    { src = gh "nvim-lua/plenary.nvim" },
    { src = gh "developedbyed/marko.nvim" },
  },
  setup = function()
    pack.setup_config("gitsigns.nvim", "config/gitsigns")
    pack.setup_config("vim-fugitive", "config/fugtive")
    pack.setup_config("diffview.nvim", "config/diff")
    pack.packadd "plenary.nvim"
    pack.packadd "nvim-lspconfig"
    pack.setup_config("neogit", "config/neogit")

    pack.safe_call("marko", function()
      pack.packadd "marko.nvim"
      require("marko").setup {
        width = 100,
        height = 100,
        border = "rounded",
        title = " Marks ",
      }
      vim.keymap.set("n", "\\\\\\", "<cmd>Marko<cr>", { desc = "vim marks" })
    end)
  end,
}
