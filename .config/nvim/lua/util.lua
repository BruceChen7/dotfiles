-- https://github.com/numToStr/dotfiles/blob/master/neovim/.config/nvim/lua/utils.lua
local api = vim.api
local cmd = api.nvim_command
local m = require("math")

local U = {}

-- Key mapping
function U.map(mode, key, result, opts)
    local options = { noremap = true, silent = true, expr = false }

    if opts then
        options = vim.tbl_extend('keep', opts, options)
    end

    api.nvim_set_keymap(mode, key, result, options)
end

function U.tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function U.random(n)
	time = os.time()
	m.randomseed(time)
	return m.random(n)
end



function U.dump(...)
    local objects = vim.tbl_map(vim.inspect, {...})
    print(unpack(objects))
end

function U.getFileFullPath()
	return vim.fn.expand('%')
end

return U


