local Hydra = require "hydra"
local gitsigns = require "gitsigns"

Hydra {
  name = "Window",
  mode = { "n" },
  body = "<space>b",
  heads = {
    {
      "p",
      function()
        vim.cmd "BufferLineCyclePrev"
      end,
    },

    {
      "n",
      function()
        vim.cmd "BufferLineCycleNext"
      end,
    },
  },
}

Hydra {
  name = "Horizontal resize",
  mode = { "n" },
  body = "<space>h",
  heads = {
    {
      "-",
      function()
        gitsigns.prev_hunk()
      end,
    },
    {
      "=",
      function()
        gitsigns.prev_hunk()
      end,
    },
  },
}

Hydra {
  name = "resize buffer",
  mode = { "n" },
  body = "<space>v",
  heads = {
    {
      ",",
      function()
        vim.cmd ":vertical resize -5<cr>"
      end,
    },

    {
      ".",
      function()
        vim.cmd ":vertical resize +5<cr>"
      end,
    },
  },
}

local ui = require "harpoon.ui"
Hydra {
  name = "harpoon bookmark",
  mode = { "n" },
  body = ",h",
  heads = {
    {
      "p",
      function()
        ui.nav_prev()
      end,
    },

    {
      "n",
      function()
        ui.nav_prev()
      end,
    },
  },
}
