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

ls.snippets = {
    lua = {
        -- Lua specific snippets go here.
        s("req", fmt("local {} = require('{}')", { i(1), rep(1) })),
    },
}
