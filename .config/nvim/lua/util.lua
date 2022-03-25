-- https://github.com/numToStr/dotfiles/blob/master/neovim/.config/nvim/lua/utils.lua
local api = vim.api
local cmd = api.nvim_command
local m = require("math")

_G.dump = function(...)
	print(vim.inspect(...))
end

_G.profile = function(cmd, times)
	times = times or 100
	local args = {}
	if type(cmd) == "string" then
		args = { cmd }
		cmd = vim.cmd
	end
	-- 获取开始时间
	local start = vim.loop.hrtime()
	for _ = 1, times, 1 do
		local ok = pcall(cmd, unpack(args))
		if not ok then
			error("Command failed: " .. tostring(ok) .. " " .. vim.inspect({ cmd = cmd, args = args }))
		end
	end
	print(((vim.loop.hrtime() - start) / 1000000 / times) .. "ms")
end

local M = {}


M.functions = {}
-- 执行相关的函数
function M.execute(id)
	local func = M.functions[id]
	if not func then
		error("Function doest not exist: " .. id)
	end
	return func()
end

-- Key mapping
function M.map(mode, key, result, opts)
	local options = { noremap = true, silent = true, expr = false }

	if opts then
		options = vim.tbl_extend('keep', opts, options)
	end

	api.nvim_set_keymap(mode, key, result, options)
end

function M.tableLength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

function M.random(n)
    math.randomseed(os.time())
    return m.random(n)
end

function M.getFileFullPath()
	return vim.fn.expand('%')
end


function M.log(msg, hl, name)
	name = name or "Neovim"
	hl = hl or "Todo"
	vim.api.nvim_echo({ { name .. ": ", hl }, { msg } }, true, {})
end

function M.warn(msg, name)
	M.log(msg, "DiagnosticWarn", name)
end

function M.error(msg, name)
	M.log(msg, "DiagnosticError", name)
end

function M.info(msg, name)
	M.log(msg, "DiagnosticInfo", name)
end

return M
