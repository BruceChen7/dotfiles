local neogit = require "neogit"
local lspconfig_util = require "lspconfig.util"
local find_root = lspconfig_util.root_pattern ".git"

function open_neogit()
  local cwd = find_root(vim.fn.expand "%:p")
  if not cwd then
    cwd = vim.fn.getcwd()
  end
  print("open " .. cwd .. " repository")
  neogit.open { kind = "split_above", cwd = cwd }
end
vim.keymap.set("n", "<space>gg", ":lua open_neogit()<CR>", { silent = true })

vim.cmd [[
    autocmd CursorMoved NeogitCommitView lua not_use_tab_key_map()
]]

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
  -- Setting any section to `false` will make the section not render at all
  sections = {
    untracked = {
      folded = false,
    },
    unstaged = {
      folded = false,
    },
    staged = {
      folded = false,
    },
    stashes = {
      folded = true,
    },
    unpulled = {
      folded = true,
    },
    unmerged = {
      folded = false,
    },
    recent = {
      folded = true,
    },
  },
  -- override/add mappings
  mappings = {
    -- modify status buffer mappings
    status = {
      -- Adds a mapping with "B" as key that does the "BranchPopup" command
      -- ["B"] = "BranchPopup",
      ["="] = "Toggle",
      -- use tab h to switch buffers
      ["<tab>"] = "",
    },
  },
}

set_tabkey_for_neogit = 0
function not_use_tab_key_map()
  if set_tabkey_for_neogit == 1 then
    return
  end
  status = require "neogit.status"
  if status == nil or status.commit_view == nil or not status.commit_view.buffer then
    return
  end
  local commit_view = status.commit_view
  -- dump(status.commit_view)
  local mappings = commit_view.buffer.mmanager.mappings["<tab>"]
  if mappings == nil then
    commit_view.buffer.mmanager.register()
    return
  end
  local opts = { noremap = true }
  vim.api.nvim_buf_set_keymap(0, "n", "<tab>", "<Nop>", opts)
  commit_view.buffer.mmanager.mappings["="] = mappings
  commit_view.buffer.mmanager.mappings["<tab>"] = nil
  commit_view.buffer.mmanager.register()
  set_tabkey_for_neogit = 1
end
