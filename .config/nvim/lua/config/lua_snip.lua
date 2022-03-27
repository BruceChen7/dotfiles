local ls = require "luasnip"
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
ls.config.set_config {
  history = true,
  -- Update more often, :h events for more info.
  update_events = "TextChanged,TextChangedI",

  enable_autosnippets = true,
}

-- <c-l> is selecting within a list of options.
-- u.map("i", "<c-l>", ":lua change_choice()<CR>")

-- u.map("i", "<c-u>", require "luasnip.extras.select_choice")

-- shorcut to source my luasnips file again, which will reload my snippets
vim.keymap.set("n", "<leader>ll", ":source ~/.config/nvim/lua/config/lua_snip.lua<CR>")

-- <c-l> is selecting within a list of options.
vim.keymap.set("i", "<c-l>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end

-- https://github.com/L3MON4D3/LuaSnip/issues/81
-- https://github.com/rafamadriz/friendly-snippets/blob/main/snippets/go.json
ls.add_snippets(nil, {
  all = {
    s("todo", {
      c(
        1,
        { t "TODO(ming.chen): ", t "FIXME(ming.chen): ", t "TODONT(ming.chen): ", t "TODO(anybody please help me): " }
      ),
    }),
  },
  lua = {
    -- Lua specific snippets go here.
    s("req", fmt("local {} = require('{}')", { i(1), rep(1) })),
  },
  go = {
    s("im", fmt("import {}", { i(1) })),
    s("co", fmt("const {} = {}", { i(1), i(2) })),
    s("cos", fmt("const (\n{} = {}\n)", { i(1), i(2) })),
    s("map", fmt("map[{}]{}", { i(1), i(2) })),
    s("if", fmt("if {} {{\n\t {} \n}}", { i(1), i(2) })),
    s("el", fmt("else {{\n\t{}\n}}", { i(1) })),
    -- use default
    s("for", fmt("for {} = 0; {} < {}; {}++ {{ \n\t {} \t\n}}", { i(1, "i"), rep(1), i(2), rep(1), i(3) })),
    s("go", fmt("go func({}) {{ \n\t {} }}", { i(1), i(2) })),
    s("tf", fmt("func Test{}(t *testing.T) {{ \n\t {} }}", { i(0), i(1) })),
  },
})
