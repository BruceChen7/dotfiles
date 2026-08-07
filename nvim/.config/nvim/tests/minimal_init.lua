-- Minimal init for plenary busted tests of lua/pi/cr pure logic.
-- Isolated from the user's full config: only plenary + this repo's lua dir.
-- Usage: nvim --headless -u tests/minimal_init.lua \
--          -c "PlenaryBustedDirectory tests/pi_cr {minimal_init = 'tests/minimal_init.lua'}"

local src = debug.getinfo(1, "S").source:gsub("^@", "")
if not src:match "^/" then
  src = vim.fn.getcwd() .. "/" .. src
end
local config_root = src:match "^(.*)/tests/"
local plenary_dir = vim.fn.stdpath "data" .. "/lazy/plenary.nvim"

vim.opt.rtp:prepend(config_root)
vim.opt.rtp:prepend(plenary_dir)

-- rtp changes after startup do not refresh package.path; seed it explicitly
-- so `require "pi.cr.*"` and `require "plenary.*"` resolve in specs.
package.path = config_root
  .. "/lua/?.lua;"
  .. config_root
  .. "/lua/?/init.lua;"
  .. plenary_dir
  .. "/lua/?.lua;"
  .. plenary_dir
  .. "/lua/?/init.lua;"
  .. package.path
