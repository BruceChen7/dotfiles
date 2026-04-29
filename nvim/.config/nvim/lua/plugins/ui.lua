local pack = require "core.pack"
local gh = pack.github

return {
  name = "ui",
  specs = {
    { src = gh "EdenEast/nightfox.nvim" },
    { src = gh "rebelot/kanagawa.nvim" },
    { src = gh "sainnhe/gruvbox-material" },
    { src = gh "catppuccin/nvim", name = "catppuccin", version = "main" },
    { src = gh "yorumicolors/yorumi.nvim" },
    { src = gh "daschw/leaf.nvim" },
    { src = gh "nvim-mini/mini.icons" },
    { src = gh "nvim-mini/mini.nvim", name = "mini.nvim" },
  },
  setup = function()
    pack.packadd "nightfox.nvim"
    pack.packadd "kanagawa.nvim"
    pack.packadd "gruvbox-material"
    pack.packadd "catppuccin"
    pack.packadd "yorumi.nvim"

    pack.safe_call("mini.icons", function()
      pack.packadd "mini.icons"
      require("mini.icons").setup()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end)

    pack.safe_call("leaf", function()
      pack.packadd "leaf.nvim"
      require("leaf").setup { theme = "dark" }
    end)

    pack.setup_config("mini.nvim", "config/mini")
  end,
}
