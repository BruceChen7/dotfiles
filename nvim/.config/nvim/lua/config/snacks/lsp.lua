---@diagnostic disable: missing-parameter
local M = {}

M.setup = function()
  local lsp_keymaps = {
    {
      "gd",
      function()
        Snacks.picker.lsp_definitions()
      end,
      desc = "Goto Definition",
    },
    {
      "gD",
      function()
        Snacks.picker.lsp_declarations()
      end,
      desc = "Goto Declaration",
    },
    {
      "grr",
      function()
        Snacks.picker.lsp_references()
      end,
      nowait = true,
      desc = "References",
    },
    {
      "\\gi",
      function()
        Snacks.picker.lsp_implementations()
      end,
      desc = "Goto Implementation",
    },
    {
      "\\gy",
      function()
        Snacks.picker.lsp_type_definitions()
      end,
      desc = "Goto T[y]pe Definition",
    },
    {
      "<c-\\>",
      function()
        Snacks.terminal()
      end,
      desc = "Terminal",
      mode = { "n", "t" },
    },
    {
      "gs",
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = "LSP Symbols",
    },
    {
      "<leader>sS",
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = "LSP Workspace Symbols",
    },
  }

  for _, keymap in ipairs(lsp_keymaps) do
    vim.keymap.set(keymap.mode or "n", keymap[1], keymap[2], {
      desc = keymap.desc,
      noremap = true,
      nowait = keymap.nowait,
    })
  end
end

return M