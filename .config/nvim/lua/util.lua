-- https://github.com/numToStr/dotfiles/blob/master/neovim/.config/nvim/lua/utils.lua
local api = vim.api
local cmd = api.nvim_command

local U = {}

-- Key mapping
function U.map(mode, key, result, opts)
    local options = { noremap = true, silent = true, expr = false }

    if opts then
        options = vim.tbl_extend('keep', opts, options)
    end

    api.nvim_set_keymap(mode, key, result, options)
end
return U

