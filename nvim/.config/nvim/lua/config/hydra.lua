local Hydra = require "hydra"
local gitsigns = require "gitsigns"
local before = require "before"
local ufo = require "ufo"

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
      { desc = "previous buffer" },
    },
  },

  {
    "n",
    function()
      vim.cmd "BufferLineCycleNext"
    end,
    { desc = "next buffer" },
  },
}

Hydra {
  name = "edit pos navigation",
  mode = { "n" },
  body = "<space>g",
  heads = {
    {
      ";",
      function()
        before.jump_to_last_edit()
      end,
      { desc = "last edit position" },
    },
    {
      ",",
      function()
        before.jump_to_next_edit()
      end,
      { desc = "next edit position" },
    },
  },
}

Hydra {
  name = "go to closed fold",
  mode = { "n" },
  body = "zg",
  heads = {
    {
      "j",
      function()
        ufo.goNextClosedFold()
      end,
      { desc = "next fold" },
    },
    {
      "k",
      function()
        ufo.goPreviousClosedFold()
      end,
      { desc = "previous fold" },
    },
  },
}

Hydra {
  name = "git hunk navigation",
  mode = { "n" },
  body = "<space>h",
  heads = {
    {
      "-",
      function()
        gitsigns.prev_hunk()
      end,
      { desc = "previous hunk", mode = { "n" } },
    },
    {
      "=",
      function()
        gitsigns.next_hunk()
      end,
      { desc = "next hunk", mode = { "n" } },
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
  body = "<space>h",
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
