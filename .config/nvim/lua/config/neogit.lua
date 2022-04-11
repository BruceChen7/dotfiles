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

function set_window_key_map()
  if vim.o.filetype == "NeogitCommitView" or vim.o.filetype == "NeogitStatus" then
    vim.keymap.set("n", "<tab>h", "<c-w>h")
    vim.keymap.set("n", "<tab>j>", "<c-w>j")
    vim.keymap.set("n", "<tab>k", "<c-w>k")
    vim.keymap.set("n", "<tab>l", "<c-w>l")
  end
end

-- function set_commit_view_window()
--   if vim.o.filetype == "NeogitCommitView" or vim.o.filetype == "NeogitStatus" then
--     vim.keymap.set("n", "<c-h", "<c-w>h")
--     vim.keymap.set("n", "<c-j>", "<c-w>j")
--     vim.keymap.set("n", "<c-k>", "<c-w>k")
--     vim.keymap.set("n", "<c-l>", "<c-w>l")
--   end
-- end

vim.cmd [[
    autocmd FileType DiffviewFiles lua set_window_key_map()
    autocmd FileType NeogitStatus lua set_window_key_map()
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
      ["B"] = "BranchPopup",
      ["="] = "Toggle",
      -- use tab h to switch buffers
      ["<tab>"] = "",
    },
  },
}
