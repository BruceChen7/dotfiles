local pack = require "core.pack"
local gh = pack.github

return {
  name = "lsp",
  specs = {
    { src = gh "neovim/nvim-lspconfig" },
    { src = gh "junnplus/lsp-setup.nvim" },
    { src = gh "williamboman/mason.nvim" },
    { src = gh "williamboman/mason-lspconfig.nvim" },
    { src = gh "linrongbin16/lsp-progress.nvim" },
    { src = gh "VidocqH/lsp-lens.nvim" },
    { src = gh "rachartier/tiny-inline-diagnostic.nvim" },
    { src = gh "nvim-lua/lsp_extensions.nvim" },
  },
  setup = function()
    -- pack.safe_call("lsp-progress", function()
    --   pack.packadd "lsp-progress.nvim"
    --   require("lsp-progress").setup()
    -- end)

    -- pack.safe_call("lsp-lens", function()
    --   pack.packadd "lsp-lens.nvim"
    --   require("lsp-lens").setup {
    --     enable = true,
    --     sections = {
    --       definition = false,
    --       references = true,
    --       implementation = true,
    --     },
    --     ignore_filetype = {
    --       "fern",
    --       "NeogitStatus",
    --       "DiffviewFiles",
    --     },
    --   }
    -- end)

    pack.safe_call("tiny-inline-diagnostic", function()
      pack.packadd "tiny-inline-diagnostic.nvim"
      require("tiny-inline-diagnostic").setup {
        options = {
          multilines = { enabled = true },
          show_source = { enabled = false },
        },
      }
      require("tiny-inline-diagnostic").enable()
      vim.keymap.set("n", "\\td", function()
        require("tiny-inline-diagnostic").toggle()
      end, { desc = "Toggle Tiny Inline Diagnostic" })
    end)

    pack.packadd "mason.nvim"
    pack.packadd "mason-lspconfig.nvim"
    pack.packadd "nvim-lspconfig"
    pack.setup_config("lsp-setup.nvim", "config/lsp")
  end,
}
