-- 主题和颜色方案插件
return {
  -- colorscheme
  { "EdenEast/nightfox.nvim" },

  { "rebelot/kanagawa.nvim" },

  {
    "daschw/leaf.nvim",
    config = function()
      require("leaf").setup { theme = "dark" }
    end,
  },
  {
    "sainnhe/gruvbox-material",
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    build = ":CatppuccinCompile",
    enabled = true,
    opts = {
      transparent = true,
      term_colors = true,
      -- 关闭启动时的集成自动探测（会扫描 pack 目录并 require pckr/lazy，约 10~15ms）。
      -- 下面显式列出当前已安装插件的集成，效果与自动探测一致，但省掉探测开销。
      -- 以后新增插件需要 catppuccin 样式时，把对应集成名加到这里即可。
      auto_integrations = false,
      integrations = {
        blink_cmp = true,
        dap = true,
        diffview = true,
        flash = true,
        fzf = true,
        gitsigns = true,
        harpoon = true,
        lsp_trouble = true,
        mason = true,
        mini = true,
        neogit = true,
        render_markdown = true,
        snacks = true,
        ufo = true,
      },
    },
  },

  { "yorumicolors/yorumi.nvim" },
}
