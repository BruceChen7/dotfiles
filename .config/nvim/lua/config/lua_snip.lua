local ls = require("luasnip")
-- create snippet
-- s(context, nodes, condition, ...)
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node


-- Function Node
-- Takes a function that returns text
local f = ls.function_node

-- This a choice snippet. You can move through with <c-l> (in my config)
-- c(1, { t {"hello"}, t {"world"}, }),
--
-- The first argument is the jump position
-- The second argument is a table of possible nodes.
-- Note, one thing that's nice is you don't have to include
-- the jump position for nodes that normally require one (can be nil)
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node

-- This is a format node.
-- It takes a format string, and a list of nodes
-- fmt(<fmt_string>, {...nodes})
local fmt = require("luasnip.extras.fmt").fmt
-- repeat(<position>)
local rep = require("luasnip.extras").rep

-- Every unspecified option will be set to the default.
ls.config.set_config({
	history = true,
	-- Update more often, :h events for more info.
	update_events = "TextChanged,TextChangedI",

    enable_autosnippets = true,
})

local u = require "util"

function change_choice()
    if ls.choice_active() then
        ls.change_choice(1)
    end
end

-- <c-l> is selecting within a list of options.
-- u.map("i", "<c-l>", ":lua change_choice()<CR>")

-- u.map("i", "<c-u>", require "luasnip.extras.select_choice")

-- shorcut to source my luasnips file again, which will reload my snippets
u.map('n', '<leader>lf', ":source ~/.config/nvim/lua/config/lua_snip.lua<CR>")
u.map("i", "<c-l>", ":lua change_choice()<CR>")

-- https://github.com/L3MON4D3/LuaSnip/issues/81
ls.add_snippets(nil, {
        lua = {
            -- Lua specific snippets go here.
            s("req", fmt("local {} = require('{}')", { i(1), rep(1) })),
        },
        go = {
            s("im", fmt("import {}", {i(1)})),
            s("co", fmt("const {} = {}", {i(1), i(2)})),
            s("cos", fmt("const (\n{} = {}\n)", {i(1), i(2)})),
            s("map", fmt("map[{}]{}", {i(1), i(2)})),
            s("if", fmt("if {} {{\n\t {} \n}}", {i(1), i(2)})),
            s("el", fmt("else {{\n\t{}\n}}", {i(1)} )),
            -- s("ir", fmt("if err != nil {{\n\t {} return {} {} }}\n", {i(1)}, {i(2)}, {i(3)})),
        },
    }
)
