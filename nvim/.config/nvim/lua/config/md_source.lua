local source = {}
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

local relative_path = function(a, b)
  local Path = require "plenary.path"
  return Path:new(a):make_relative(b)
end

-- request value
-- name string
-- option table|nil
-- priority integer|nil
-- trigger_characters string[]|nil
-- keyword_pattern string|nil
-- keyword_length integer|nil
-- max_item_count integer|nil
-- group_index integer|nil
-- entry_filter nil|function(entry: cmp.Entry, ctx: cmp.Context): boolean
source.complete = function(self, request, callback)
  print(vim.inspect(request))
  local q = string.sub(request.context.cursor_before_line, request.offset)

  local trigger_character = request.context.cursor_before_line

  print("q is ", vim.inspect(q), "trigger_character is ", trigger_character)
  -- if trigger_character not starts with [[
  if string.sub(trigger_character, 1, 2) ~= "[[" then
    print("not starts with [[ ", trigger_character)
    return
  end

  local root = find_root_dir()
  if not root then
    return
  end

  -- deal with event
  local items = {}
  local function on_event(_, data, event)
    if event == "stdout" then
      local messages = data
      print(vim.inspect(messages))

      -- 遍历messages
      for _, m in ipairs(messages) do
        -- 获取当前buffer 的绝对路径
        local buf_path = vim.api.nvim_buf_get_name(0)
        -- 将m相对路径转为绝对路径
        local m_path = vim.fn.fnamemodify(m, ":p")
        local rel_path = relative_path(m_path, buf_path)

        print("buf_path is ", buf_path, "rel_path is ", rel_path, "m_path is ", m_path)
      end

      if request.max_item_count ~= nil and #items >= request.max_item_count then
        -- 停止该job
        vim.fn.jobstop(self.running_job_id)
        -- 给出相关的items
        callback { items = items, isIncomplete = false }
        return
      end

      callback { items = items, isIncomplete = true }
    end

    if event == "stderr" and request.option.debug then
      vim.cmd "echohl Error"
      vim.cmd('echomsg "' .. table.concat(data, "") .. '"')
      vim.cmd "echohl None"
    end

    if event == "exit" then
      callback { items = items, isIncomplete = false }
    end
  end

  self.timer:stop()
  -- 开启一个timer
  self.timer:start(
    request.option.debounce or 100,
    0,
    vim.schedule_wrap(function()
      local cmd = string.format("fd  --follow --type file --color never '%s' %s", q, root)
      print("cmd is ", cmd)
      vim.fn.jobstop(self.running_job_id)
      self.running_job_id = vim.fn.jobstart(cmd, {
        on_stderr = on_event,
        on_stdout = on_event,
        on_exit = on_event,
        cwd = root or vim.fn.getcwd(),
      })
    end)
  )
end

local ok, cmp = pcall(require, "cmp")

if ok then
  cmp.register_source("md_link", source.new())
elseif not ok then
end

return source
