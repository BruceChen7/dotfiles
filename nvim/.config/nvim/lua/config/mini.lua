require("mini.cursorword").setup { delay = 50 }
-- https://github.com/khuedoan/dotfiles/blob/5f5035e899568718501d6c1688b816019ddc918d/.config/nvim/lua/plugins.lua#L250
require("mini.surround").setup {
  mappings = {
    add = "gza",
    delete = "gzd",
    find = "gzf",
    replace = "gzr",
    highlight = "gzh",
    update_n_lines = "gzn",
  },
}
require("mini.trailspace").setup {}
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.md",
  callback = function()
    MiniTrailspace.trim()
  end,
})

require("mini.pairs").setup {}

local miniclue = require "mini.clue"
miniclue.setup {
  triggers = {
    -- Leader triggers
    { mode = "n", keys = "<leader>" },
    { mode = "n", keys = "\\" },
    { mode = "v", keys = "\\" },
    { mode = "v", keys = "<leader>" },
    { mode = "n", keys = "g" },
    { mode = "v", keys = "g" },
    { mode = "n", keys = "n" },
    { mode = "n", keys = "z" },
  },
  clues = {
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.windows(),
    miniclue.gen_clues.registers(),
  },
  window = {
    delay = 200,
  },
}

-- https://github.com/oncomouse/dotfiles/blob/2a58fa952eacb751ff24361efd81308716a759c1/conf/vim/lua/dotfiles/plugins/mini-nvim.lua#L104
-- https://github.com/xixiaofinland/dotfiles/blob/main/.config/nvim/lua/plugins/mini.lua
-- https://www.reddit.com/r/neovim/comments/1cvur6s/what_custom_text_objects_do_you_use/
-- use `if` 和 `af` 来选择函数调用
local gen_spec = require("mini.ai").gen_spec
require("mini.ai").setup {
  custom_textobjects = {
    o = gen_spec.treesitter({ a = "@loop.outer", i = "@loop.inner" }, {}),
    m = gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
    i = gen_spec.treesitter({ a = "@conditional.outer", i = "@conditional.inner" }, {}),
  },
}

-- https://github.com/pkazmier/nvim/blob/main/lua/plugins/mini/statusline.lua
require("mini.statusline").setup {}
require("mini.files").setup {
  windows = {
    preview = true,
  },
}
vim.keymap.set("n", "<leader>mf", function()
  local files = require "mini.files"
  files.open(vim.api.nvim_buf_get_name(0))
end, { desc = "open files" })

-- require("mini.completion").setup {
--   delay = { completion = 50, info = 100, signature = 50 },
--   lsp_completion = {
--     -- `source_func` should be one of 'completefunc' or 'omnifunc'.
--     source_func = "completefunc",
--     -- `auto_setup` should be boolean indicating if LSP completion is set up
--     -- on every `BufEnter` event.
--     auto_setup = true,
--     -- A function which takes LSP 'textDocument/completion' response items
--     -- and word to complete. Output should be a table of the same nature as
--     -- input items. Common use case is custom filter/sort.
--     -- process_items = --<function: MiniCompletion.default_process_items>,
--   },
-- }

-- use c-j and c-k to navigate completion
-- vim.keymap.set("i", "<C-j>", [[pumvisible() ? "\<C-n>" : ""]], { expr = true })
-- vim.keymap.set("i", "<C-k>", [[pumvisible() ? "\<C-p>" : ""]], { expr = true })

require("mini.pick").setup {
  mappings = {
    move_down = "<C-j>",
    move_up = "<C-k>",
  },
}

-- require("mini.visits").setup {
--   list = {
--     filter = function(data)
--       -- 获取当前工作目录
--       local cwd = vim.fn.getcwd()
--       -- if buf_path contains cwd then return true
--       return vim.startswith(data.path, cwd)
--     end,
--   },
-- }

-- vim.keymap.set("n", "<m-b>", "<cmd>lua MiniVisits.select_path()<cr>")

require("mini.extra").setup {}

-- local buf_num_2_id = {}
-- local get_buffer_num = function(buf_id)
--   if buf_num_2_id[buf_id] == nil then
--     local max = buf_num_2_id["max"] or 0
--     buf_num_2_id[buf_id] = max + 1
--     buf_num_2_id["max"] = max + 1
--   end
--   return buf_num_2_id[buf_id]
-- end
--
-- local tweak_buffer_num_2_id = function()
--   local max = 0
--   local visible_buffers = require("utils").find_all_visible_buffers()
--   for _, buf_id in ipairs(visible_buffers) do
--     max = math.max(max, buf_num_2_id[buf_id] or 0)
--   end
--   buf_num_2_id["max"] = max
-- end
--
-- local set_buffer_num = function(buf_id, buf_num)
--   if buf_num_2_id[buf_id] == nil then
--     buf_num_2_id[buf_id] = buf_num
--     if buf_num_2_id["max"] == nil then
--       buf_num_2_id["max"] = 1
--     else
--       buf_num_2_id["max"] = buf_num_2_id["max"] + 1
--     end
--   end
-- end
--
-- require("mini.tabline").setup {
--   show_icons = true,
--   -- 需要设置buffer variable，这样才不会改变
--   format = function(buf_id, label)
--     local suffix = vim.bo[buf_id].modified and "+ " or ""
--     -- 如果是quickfix， 则不显示buf_num
--     if vim.bo[buf_id].buftype == "quickfix" then
--       return ""
--     end
--     local num = get_buffer_num(buf_id)
--     local buf_num = num
--     set_buffer_num(buf_id, buf_num)
--     tweak_buffer_num_2_id()
--     -- set `buf_id` to string
--     return tostring(buf_num) .. "." .. MiniTabline.default_format(buf_id, label) .. suffix
--   end,
-- }
--
-- -- use \\1 .. \\9 to get buffer
-- for i = 1, 9 do
--   vim.keymap.set("n", string.format("\\%d", i), function()
--     -- 遍历 buf_num_2_id， 如果value == i， 则返回key
--     local buffer_ids = {}
--     for k, v in pairs(buf_num_2_id) do
--       if v == i and type(k) == "number" then
--         table.insert(buffer_ids, k)
--       end
--     end
--     local buffer_id = buffer_ids[1] or -1
--     local utils = require "utils"
--     local visible_buff = utils.find_all_visible_buffers()
--     if buffer_id == -1 then
--       return
--     end
--     local in_visual_buffer = false
--     for _, v in pairs(visible_buff) do
--       if v == buffer_id then
--         in_visual_buffer = true
--         break
--       end
--     end
--     if not in_visual_buffer then
--       return
--     end
--     vim.cmd(string.format("b %d", buffer_id))
--   end, { desc = string.format("go to buffer %d", i) })
-- end
--
-- -- Reset Number
-- local reset_buffer_numbers = function()
--   buf_num_2_id = {}
--   buf_num_2_id["max"] = 0
-- end
--
-- local rebuild_buffer_numbers = function()
--   reset_buffer_numbers()
--   local visible_buffers = require("utils").find_all_visible_buffers()
--   for i, buf_id in ipairs(visible_buffers) do
--     set_buffer_num(buf_id, i)
--   end
-- end
--
-- -- Use autocmd event to trigger numbering rebuild
-- vim.api.nvim_create_autocmd({ "BufDelete", "BufWinEnter" }, {
--   callback = function()
--     rebuild_buffer_numbers()
--   end,
-- })

require("mini.notify").setup()

-- https://www.youtube.com/watch?v=cNK5kYJ7mrs&t=742s
require("mini.operators").setup {
  -- Evaluate text and replace with output
  evaluate = {
    prefix = "g=",

    -- Function which does the evaluation
    func = nil,
  },

  -- Exchange text regions
  exchange = {
    prefix = "ge",

    -- Whether to reindent new text to match previous indent
    reindent_linewise = true,
  },

  -- Multiply (duplicate) text
  multiply = {
    prefix = "gm",

    -- Function which can modify text before multiplying
    func = nil,
  },

  -- Replace text with register
  replace = {
    prefix = "gp",

    -- Whether to reindent new text to match previous indent
    reindent_linewise = true,
  },

  -- Sort text
  sort = {
    prefix = "\\gs",

    -- Function whichwhichwhichwhichwhichwhichwhichwhich does the sort
    func = nil,
  },
}
