-- herdr-nav — Neovim side
--
-- Seamless <C-h/j/k/l> navigation between Neovim splits and herdr panes.
-- Moves between Neovim splits, and at a split edge hands off to herdr so
-- focus crosses into the neighbouring herdr pane. Falls back to tmux when
-- inside a tmux session (e.g. tmux inside herdr), or does nothing when not
-- inside any multiplexer.
--
-- Only activates when $HERDR_PANE_ID is set (i.e. Neovim was spawned inside
-- a herdr pane). Load via after/plugin/ so it wins over vim-tmux-navigator
-- and other <C-h/j/k/l> mappings.

local herdr_pane = vim.env.HERDR_PANE_ID
if not herdr_pane or herdr_pane == "" then
  return
end

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end

  -- At a split edge: cross into the surrounding multiplexer.
  if herdr_pane then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == "" then
      herdr = "herdr"
    end
    vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux_cmd = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux_cmd[dir])
  end
end

local function map(lhs, wincmd, dir, desc)
  local fn = function()
    nav(wincmd, dir)
  end

  vim.keymap.set("n", lhs, fn, { silent = true, noremap = true, desc = desc })
  vim.keymap.set("x", lhs, fn, { silent = true, noremap = true, desc = desc })
end

map("<C-h>", "h", "left",  "Navigate left (herdr/Neovim)")
map("<C-j>", "j", "down",  "Navigate down (herdr/Neovim)")
map("<C-k>", "k", "up",    "Navigate up (herdr/Neovim)")
map("<C-l>", "l", "right", "Navigate right (herdr/Neovim)")
