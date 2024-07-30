local Hydra = require "hydra"
local gitsigns = require "gitsigns"
local before = require "before"
local ufo = require "ufo"

Hydra {
  name = "Window",
  mode = { "n", "t" },
  -- Do not use <space> in terminal mode, otherwise it will cause a delay of timoutlen ms when inputting <space> in terminal mode
  body = "\\b",
  heads = {
    {
      "p",
      function()
        vim.cmd "bprevious"
      end,
      { desc = "previous buffer" },
    },

    {
      "n",
      function()
        vim.cmd "bnext"
      end,
      { desc = "next buffer" },
    },
  },
}

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
      { desc = "last edit position in current file" },
    },
    {
      ",",
      function()
        vim.cmd "silent normal! g,"
      end,
      { desc = "next edit position in current file" },
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

    {
      "K",
      function()
        local winid = require("ufo").peekFoldedLinesUnderCursor()
        if not winid then
          vim.lsp.buf.hover()
        end
      end,
      { desc = "Peek Folded Lines" },
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
