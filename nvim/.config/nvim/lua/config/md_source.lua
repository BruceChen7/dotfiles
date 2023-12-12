local source = {}

local defaults = {
  keyword_length = 3,
  -- start with [[ ..]]
  keyword_pattern = "%[%[%s*([%w%-%s]*)%s*%]%]",
}

source.get_trigger_characters = function()
  return { "[" }
end
source.new = function()
  local timer = vim.uv.new_timer()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
    end,
  })
  return setmetatable({
    running_job_id = 0,
    timer = timer,
    json_decode = vim.fn.has "nvim-0.6" == 1 and vim.json.decode or vim.fn.json_decode,
  }, { __index = source })
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

source.get_keyword_length = function()
  -- 以[[ 开头，以]] 结尾
  return [[\s*\zs\(\[\+\(\w\+\)\?]]
end
-- nvim-cmp/lua/cmp/types/lsp.lua
source.complete = function(self, request, callback)
  local input = request.context.cursor_line
  print(vim.inspect(request))
  local filename = input:match "%[%[%s*([^]%]]+)%s*%]%]"
  if filename then
    print(vim.inspect(filename))
    local path = find_root_dir()
    print("root dir: " .. path)
    -- using fd to search file
    local cmd = string.format(
      "fd --type f --hidden --follow --color never --exclude .obsidian --exclude .git --absolute-path '%s' '%s'",
      filename,
      path
    )
    local result = vim.fn.system(cmd)
    print(vim.inspect(result))
    -- split result by newline
    local files = vim.split(result, "\n")

    print(vim.inspect(files))
    local items = {}
    local filterText = "[[" .. filename .. "]]"
    print("filterText: " .. filterText)
    for i = 1, #files do
      local file = files[i]
      -- trim \newline
      file = string.gsub(file, "\n", "")

      -- vim获取文件名称
      local name = vim.fn.fnamemodify(file, ":t")
      print("file: " .. file)
      print("name: " .. name)
      local entry = "[" .. name .. "](" .. file .. ")"
      print("entry: " .. entry)

      if file ~= "" then
        local row = request.context.cursor.row
        print("start is ", row)
        table.insert(items, {
          label = entry,
          word = entry,
          filterText = filterText,
          -- 用来替换原来的文本
          textEdit = {
            range = {
              start = {
                line = row - 1,
                character = 1,
              },
              ["end"] = {
                line = row - 1,
                character = 30,
              },
            },
          },
          newText = entry,
        })
      end
    end
    -- print("items: " .. vim.inspect(items))
    callback { items = items, isIncomplete = true }
  else
    callback { isIncomplete = true }
  end
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
