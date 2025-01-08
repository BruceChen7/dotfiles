local Hydra = require "hydra"
local gitsigns = require "gitsigns"
local before = require "before"

Hydra {
  name = "go to next tab page",
  mode = { "n", "t" },
  body = "\\t",
  heads = {
    {
      "n",
      function()
        vim.cmd "tabNext"
      end,
      { desc = "go to next tab" },
    },
    {
      "p",
      function()
        vim.cmd "tabprevious"
      end,
      { desc = "go to previous tab" },
    },
  },
}

Hydra {
  name = "go to last edit position in current file",
  mode = { "n" },
  body = "g;",
  heads = {
    {
      ";",
      function()
        -- use lua to get the last edit position like in normal mode g;
        vim.cmd "silent normal! g;"
      end,
      { desc = "last edit position in current file", silent = true },
    },
    {
      ",",
      function()
        vim.cmd "silent normal! g,"
      end,
      { desc = "next edit position in current file", silent = true },
    },
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
