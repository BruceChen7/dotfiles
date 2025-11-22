---@diagnostic disable: missing-parameter
local utils = require "utils"

local function get_default_branch()
  local branches = vim.fn.systemlist "git branch -a"
  if vim.v.shell_error ~= 0 then
    return "main"
  end
  local priority = { "release", "master", "main" }
  for _, target in ipairs(priority) do
    for _, branch in ipairs(branches) do
      if branch:match("^%s*" .. target .. "$") or branch:match("remotes/origin/" .. target .. "$") then
        return target
      end
    end
  end
  return "main"
end

local function get_terminal_handler(cmd_template, opts)
  opts = opts or {}
  return function()
    local cmd = cmd_template:gsub("%%:p", vim.fn.expand "%:p")
    if opts.use_root then
      cmd = cmd:gsub("%%:root", utils.find_root_dir() or vim.fn.getcwd())
    end
    cmd = cmd:gsub("%%:branch", get_default_branch())
    Snacks.terminal(cmd)
  end
end

local set_terminal_keymaps = function()
  local opts = { buffer = 0 }
  -- using <esc> to enter normal mode
  -- vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
  vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
  vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
  vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end

local terminal_autocmds = {
  -- Set terminal keymaps and handle special filetypes
  {
    event = "TermOpen",
    pattern = "term://*",
    callback = function()
      -- Set common terminal keymaps
      set_terminal_keymaps()

      -- For specific terminal types, use jk instead of <esc>
      local terminal_filetypes = { "sidekick_terminal", "snacks_terminal" }
      if vim.tbl_contains(terminal_filetypes, vim.bo.filetype) then
        vim.keymap.del("t", "<esc>", { buffer = 0 })
        vim.keymap.set("t", "jk", [[<C-\><C-n>]], { buffer = 0 })
      end
    end,
  },
  {
    event = { "TermOpen", "BufEnter" },
    pattern = "term://*",
    callback = function()
      vim.cmd "startinsert"
    end,
  },
  {
    event = { "TermClose" },
    pattern = "term://*",
    callback = function()
      if vim.v.event.status == 0 then
        vim.api.nvim_buf_delete(0, {})
        vim.notify_once "Previous terminal job was successful!"
      else
        vim.notify_once "Error code detected in the current terminal job!"
      end
    end,
  },
}

-- Create all autocmds at once
for _, autocmd in ipairs(terminal_autocmds) do
  vim.api.nvim_create_autocmd(autocmd.event, {
    group = term_augroup,
    pattern = autocmd.pattern,
    callback = autocmd.callback,
  })
end

local M = {}

M.setup = function()
  local terminal_keymaps = {
    {
      "<c-\\>",
      function()
        Snacks.terminal()
      end,
      desc = "Terminal",
      mode = { "n", "t" },
    },
    {
      "<leader>tl",
      get_terminal_handler 'git log -p "%:p"',
      desc = "git log for this file in terminal",
    },
    {
      "\\tf",
      get_terminal_handler "git diff %:branch -- %:p",
      desc = "git diff for this file in terminal",
    },
    {
      "\\tb",
      get_terminal_handler "tig blame %:p",
      desc = "tig blame current file in terminal",
    },
    {
      "<leader>tt",
      get_terminal_handler('tig -C "%:root"', { use_root = true }),
      desc = "open tig",
    },
    {
      "\\gm",
      get_terminal_handler("git diff %:branch -- %:root", { use_root = true }),
      desc = "open git diff in terminal",
    },
    {
      "\\\fh",
      get_terminal_handler "git diff %:branch -- %:p",
      desc = "file differences",
    },
  }

  utils.register_keymaps(terminal_keymaps)
end

return M
