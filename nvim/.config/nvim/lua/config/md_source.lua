local source = {}

source.get_trigger_characters = function()
  return { "[" }
end
source.new = function()
  return setmetatable({}, { __index = source })
end

local find_root_dir = function()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local lspconfig_util = require "lspconfig.util"
  return lspconfig_util.root_pattern(".obsidian", ".git")(buf_name)
end

local relative_path = function(dest, src)
  -- call shell command realpath
  local cmd = string.format("realpath --relative-to='%s' '%s'", src, dest)
  local result = vim.fn.system(cmd)
  return string.gsub(result, "\n", "")
end

-- 这个不触发pattern的补全，而是触发补全的场景下，如果继续输入, 高亮匹配的部分，并匹配
source.get_keyword_pattern = function()
  return [[\k\+]]
end

-- nvim-cmp/lua/cmp/types/lsp.lua
source.complete = function(self, request, callback)
  local input = request.context.cursor_line
  print("request is ", vim.inspect(request))
  print("input is ", vim.inspect(input))

  local comp = function(result)
    -- print(vim.inspect(result))
    -- split result by newline

    local items = {}

    for i = 1, #result do
      local file = result[i]
      -- trim \newline
      file = string.gsub(file, "\n", "")

      -- vim获取文件名称
      local name = vim.fn.fnamemodify(file, ":t")
      local entry = "[" .. name .. "](" .. file .. ")"
      if file == "" or i == 100 then
        break
      end

      local row = request.context.cursor.row
      table.insert(items, {
        label = entry,
        -- seems not working
        -- 用来替换原来的文本
        -- vim.api.nvim_strwidth(来获取文本的宽度)
        -- character
        -- textEdit = {
        --   range = {
        --     start = {
        --       line = row - 1,
        --       character = 0,
        --     },
        --     ["end"] = {
        --       line = row - 1,
        --       character = request.context.cursor.col + 1000,
        --     },
        --   },
        --   newText = "mysql中的表",
        -- },
        -- textEdit = {
        --   range = {
        --     start = {
        --       line = row - 1,
        --       character = 0,
        --     },
        --     ["end"] = {
        --       line = row - 1,
        --       character = request.context.cursor.col - 1 + 2,
        --     },
        --   },
        --   newText = entry,
        -- },
      })
    end
    -- items size is 0
    if #items == 0 then
      callback()
      return
    end
    print("items: " .. vim.inspect(items))
    callback { items = items }
  end

  -- local row = request.context.cursor.row
  -- sleep 100ms
  -- vim.defer_fn(function()
  --   print "sleep 100ms"
  --   local items = {
  --     {
  --       label = "[hello]hello你好1",
  --       textEdit = {
  --         range = {
  --           start = {
  --             line = row - 1,
  --             character = 0,
  --           },
  --           ["end"] = {
  --             line = row - 1,
  --             character = 100,
  --           },
  --         },
  --         newText = "[hello]hello你好",
  --       },
  --     },
  --
  --     {
  --       label = "[hello]hello你好2",
  --       textEdit = {
  --         range = {
  --           start = {
  --             line = row - 1,
  --             character = 0,
  --           },
  --           ["end"] = {
  --             line = row - 1,
  --             character = 100,
  --           },
  --         },
  --         newText = "[hello]hello你好2",
  --       },
  --     },
  --   }
  --   callback {
  --     isIncomplete = true,
  --     items = items,
  --   }
  --   print(vim.inspect(items))
  --   if true then
  --     return
  --   end
  -- end, 20)

  local filename = input:match "%[%[%s*([^]%]]+)%s*%]%]"
  if filename == "" or not filename then
    return
  end
  print("filename is ", vim.inspect(filename))
  local path = find_root_dir()
  -- using fd to search file
  local cmd = string.format(
    "fd --type f --hidden --follow --color never --exclude .obsidian --exclude .git --absolute-path '%s' '%s'",
    filename,
    path
  )
  print("cmd is", vim.inspect(cmd))
  -- -- add a job
  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if #data == 0 then
        return
      end
      if #data == 1 and data[1] == "" then
        return
      end
      -- print("data is ", vim.inspect(data))
      comp(data)
    end,
  })
end

source.get_position_encoding_kind = function()
  return "utf-8"
end

local ok, cmp = pcall(require, "cmp")

if ok then
  cmp.register_source("md_link", source.new())
elseif not ok then
end
return source
