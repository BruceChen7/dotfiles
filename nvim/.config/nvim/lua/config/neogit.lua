local neogit = require "neogit"
local lspconfig_util = require "lspconfig.util"
local find_root = lspconfig_util.root_pattern ".git"
local neogit_config = require "neogit.config"
local status = neogit_config.values.mappings.status
status["<tab>"] = nil
status["="] = "Toggle"

function open_neogit()
  local cwd = find_root(vim.fn.expand "%:p")
  if not cwd then
    cwd = vim.fn.getcwd()
  end
  print("open " .. cwd .. " repository")
  neogit.open {}
end
vim.keymap.set("n", "<space>gg", ":lua open_neogit()<CR>", { silent = true })

neogit.setup {
  disable_signs = false,
  disable_hint = false,
  disable_context_highlighting = false,
  disable_commit_confirmation = true,
  auto_refresh = true,
  disable_builtin_notifications = false,
  commit_popup = {
    kind = "split_above",
  },
  -- Change the default way of opening neogit
  kind = "split_above",
  -- customize displayed signs
  signs = {
    -- { CLOSED, OPENED }
    section = { ">", "v" },
    item = { ">", "v" },
    hunk = { "", "" },
  },
  integrations = {
    diffview = true,
  },
  mappings = {
    status = status,
  },
}
