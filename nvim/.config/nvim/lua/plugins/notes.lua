local pack = require "core.pack"
local gh = pack.github

return {
  name = "notes",
  specs = {
    { src = gh "obsidian-nvim/obsidian.nvim" },
    { src = gh "MeanderingProgrammer/render-markdown.nvim" },
    { src = gh "skywind3000/asynctasks.vim" },
    { src = gh "skywind3000/asyncrun.vim" },
    { src = gh "skywind3000/vim-preview" },
    { src = gh "skywind3000/vim-quickui" },
  },
  setup = function()
    pack.packadd "asynctasks.vim"
    pack.packadd "vim-preview"
    pack.packadd "vim-quickui"
    pack.setup_config("asyncrun.vim", "config/cmd")

    pack.safe_call("obsidian", function()
      pack.packadd "obsidian.nvim"
      require("obsidian").setup {
        legacy_commands = false,
        workspaces = {
          {
            name = "personal",
            path = "~/work/notes",
          },
        },
      }
    end)

    pack.safe_call("render-markdown", function()
      pack.packadd "render-markdown.nvim"
      require("render-markdown").setup {
        file_types = { "markdown", "Avante" },
        code = {
          sign = false,
          style = "normal",
        },
      }
    end)
  end,
}
