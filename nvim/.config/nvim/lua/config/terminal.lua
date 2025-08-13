function _G.set_terminal_keymaps()
  local opts = { buffer = 0 }
  -- using <esc> to enter normal mode
  -- vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
  -- vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
  -- vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
  -- vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
  -- vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  -- vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end

local Terminal = require("toggleterm.terminal").Terminal

local lspconfig_util = require "lspconfig.util"
local find_root = lspconfig_util.root_pattern ".git"

local function _Tig_TOGGLE()
  local root = find_root(vim.fn.expand "%:p")
  if not root then
    -- FIXME(ming.chen): use vim.notify()
    -- vim.notify("use working directory instead", vim.log.levels.INFO)
    root = vim.fn.getcwd()
  end
  local tig = Terminal:new { cmd = "tig -C " .. root, hidden = true }
  tig:toggle()
end

local function get_zig_test_declaration()
  -- 定义一个函数来获取Zig测试声明
  local ts_utils = require "nvim-treesitter.ts_utils" -- 导入Treesitter的utils模块
  local node = ts_utils.get_node_at_cursor() -- 获取当前光标下的节点
  -- 获取父parent node
  while node and node:type() ~= "TestDecl" do
    -- print(node:type()) -- 打印节点类型（调试用）
    node = node:parent() -- 获取父节点
  end
  if node and node:type() == "TestDecl" then
    -- 如果节点类型是TestDecl，则返回true
    return true
  else
    -- 否则返回false
    return false
  end
end

-- Test command configurations
local TEST_CONFIG = {
  go = {
    tags = "integration_test,unit_test",
    gcflags = "all=-l",
    default_project = "luckyvideo",
  },
}

-- Validate that a function name is a valid test function
local function validate_test_function(function_name)
  if not function_name then
    vim.notify "No function found"
    return false
  end
  if string.sub(function_name, 1, 4) ~= "Test" then
    vim.notify "Test function not found"
    return false
  end
  return true
end

-- Get project name based on root directory
local function get_project_name_by_root(root)
  local last_part = string.match(root, "([^/]+)$")
  local project_name = TEST_CONFIG.go.default_project

  if last_part == "ecommerce" then
    project_name = "core"
  elseif last_part == "knowledge-platform" then
    last_part = "knowledgeplatform"
  end

  return project_name, last_part
end

-- Build environment variables for Go testing
local function build_go_test_env(utils, project_name, module_name)
  if not utils.is_mac() or not utils.is_in_working_dir() then
    return ""
  end

  return string.format(
    "export env=test && export cid=global && export PROJECT_NAME=%s && export DISABLE_PPROF=true && export MODULE_NAME=%s && export SP_UNIX_SOCKET=/tmp/spex.sock",
    project_name,
    module_name
  )
end

-- Build the complete Go test command
local function build_go_test_command(utils, dir, function_name)
  local cwd = vim.fn.getcwd()
  local relative_path = utils.relative_path(cwd, dir)
  local go_executable = vim.fn.executable "xgo" == 1 and "xgo" or "go"

  local root = utils.find_root_dir()
  local project_name, module_name = get_project_name_by_root(root)
  local env_cmd = build_go_test_env(utils, project_name, module_name)

  local test_cmd = string.format(
    "%s test -count=1 ./%s -tags='%s' -gcflags=%s -v -run %s",
    go_executable,
    relative_path,
    TEST_CONFIG.go.tags,
    TEST_CONFIG.go.gcflags,
    function_name
  )

  return env_cmd == "" and test_cmd or env_cmd .. " && " .. test_cmd
end

-- Main function to get appropriate test command based on file type
local function get_test_command()
  vim.api.nvim_command "redraw"

  local buf_name = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local filetype = vim.bo.filetype

  local handlers = {
    zig = function()
      if not get_zig_test_declaration() then
        return nil
      end
      return string.format("cd %s && zig test %s", dir, buf_name)
    end,
    python = function()
      return string.format("cd %s && python3 -m unittest discover -s ./", dir)
    end,
    go = function()
      local utils = require "utils"
      local function_name = utils.get_go_nearest_function()
      if not validate_test_function(function_name) then
        return nil
      end
      return build_go_test_command(utils, dir, function_name)
    end,
  }

  local handler = handlers[filetype]
  return handler and handler() or nil
end

-- Helper function to get SPEX configuration based on platform
local function get_spex_config()
  local utils = require "utils"
  if utils.is_m1_mac() then
    return {
      command = "socat -d -d -d UNIX-LISTEN:${SP_UNIX_SOCKET},reuseaddr,fork TCP:${SP_AGENT_DOMAIN}",
    }
  elseif utils.is_mac() then
    return {
      command = "inp-client --mode=forward --local_network=unix --local_address=/tmp/spex.sock --remote_network=unix --remote_address=/run/spex/spex.sock",
    }
  end
  return nil
end

-- Helper function to start SPEX job
local function start_spex_job(config)
  vim.fn.jobstart(config.command, {
    on_stdout = function(_, _) end,
  })
end

-- Helper function to run test command
local function run_test_command(cmd)
  vim.fn["asyncrun#run"]("", {
    mode = "async",
    raw = false,
    -- Error format pattern for parsing compiler output
    -- %.%# - Match any characters up to a newline
    -- %trror: - Match "error:" (case-insensitive)
    -- %m - Match error message
    -- %f:%l:%c: - Match filename:line:column:
    -- %m - Match error message
    -- %f:%l: - Match filename:line:
    -- %m - Match error message
    -- %f:%l:%c - Match filename:line:column
    -- %m - Match error message
    -- errorformat = {
    --   "%.%# %trror: %m", -- Match error messages with "error:"
    --   "%f:%l:%c: %m", -- Match messages with filename:line:column:message
    --   "%f:%l: %m", -- Match messages with filename:line:message
    --   "%f:%l:%c %m", -- Match messages with filename:line:column message
    -- },
    errorformat = "%.%# %trror: %m, %f:%l:%c: %m, %f:%l: %m, %f:%l:%c %m",
  }, cmd)
end

-- 设置按键映射，按下<F2>时执行以下函数
vim.keymap.set("n", "<F2>", function()
  -- 获取测试命令
  local cmd = get_test_command()
  if cmd == nil then
    -- 如果命令为空，则返回
    return
  end

  local utils = require "utils"
  -- 加载utils模块
  local spex_config = get_spex_config()
  -- 获取spex配置
  if spex_config then
    -- 如果配置存在，则启动spex作业
    start_spex_job(spex_config)
  end

  utils.change_to_current_buffer_root_dir()
  -- 切换到当前缓冲区的根目录
  run_test_command(cmd)
  -- 运行测试命令
end, { desc = "open go test in quickfix" })
-- 设置按键映射的描述

local get_go_build_cmd = function()
  local utils = require "utils"
  if not utils.is_in_working_dir() then
    return nil
  end

  local buf_path = vim.fn.expand "%:p"
  local build_commands = {
    ["video/platform/app/shopconsole"] = "go build app/shopconsole/main.go",
    ["botapi"] = "go build cmd/main.go",
    ["coreapi"] = "go build app/chat-api/main.go",
    ["workbenchapi"] = "go build app/chat-api/main.go",
    ["bff"] = "make build-with-proto",
  }

  for pattern, cmd in pairs(build_commands) do
    if string.find(buf_path, pattern, 1, true) then
      return cmd
    end
  end
end

local get_zig_cmd = function()
  local buf_path = vim.fn.expand "%:p"

  -- This line is searching for a directory named "zig-redis" starting from the current buffer's path (`buf_path`) and
  -- looking upwards through parent directories.

  -- 1. `vim.fn.finddir()` - A Vim function that searches for a directory
  -- 2. `"zig-redis"` - The name of the directory to search for
  -- 3. `buf_path` - The full path of the current buffer/file
  -- 4. `";"` - This tells Vim to search upwards through parent directories until it finds the directory or reaches the root
  local zig_redis_path = vim.fn.finddir("zigredis", buf_path .. ";")
  -- 字符串中找到`/zigredis`
  local start, end_ = string.find(buf_path, "/zigredis")

  if start and end_ then
    -- vim 的工作目录切换到zig_redis_path
    vim.fn.chdir(zig_redis_path)
    return "zig build"
  end

  local zig_caskdb_path = vim.fn.finddir("zig-caskdb", buf_path .. ";")
  start, end_ = string.find(buf_path, "zig%-caskdb")

  -- 2. 避免与 Lua 的关键字 `end` 冲突
  if start and end_ then
    vim.fn.chdir(zig_caskdb_path)
    return "zig build"
  end
end

local get_build_cmd = function()
  local filetype = vim.bo.filetype
  if filetype == "go" then
    return get_go_build_cmd()
  end
  if filetype == "zig" then
    return get_zig_cmd()
  end
end

vim.keymap.set("n", "<F5>", function()
  local cmd = get_build_cmd()
  print("cmd is ", cmd)
  if cmd == nil then
    return
  end
  vim.fn["asyncrun#run"]("", {
    mode = "async",
    -- should be false
    raw = false,
    errorformat = "%f:%l:%c: %m",
  }, cmd)
end, { desc = "make build" })

vim.keymap.set("n", "<leader>tl", function()
  local cmd = 'git log -p "' .. vim.fn.expand "%:p" .. '"'
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open git log for this file in terminal" })

vim.keymap.set("n", "\\tf", function()
  -- cmd 为 gitdiff release 分支 和当前分支 当前buffer 所在的目录
  local cmd = "git diff release -- " .. vim.fn.expand "%:p"
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open git log for this file in terminal" })

vim.keymap.set("n", "\\tb", function()
  local current_file_path_with_name = vim.fn.expand "%:p"
  local cmd = "tig blame " .. current_file_path_with_name
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "tig blame current file in terminal" })

vim.keymap.set("n", "<leader>tt", function()
  local utils = require "utils"
  local root = utils.find_root_dir()
  if not root then
    root = vim.fn.getcwd()
  end
  local cmd = 'tig -C "' .. root .. '"'
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open tig" })

vim.keymap.set("n", "\\gm", function()
  local utils = require "utils"
  local cmd = "git diff master -- " .. utils.find_root_dir()
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "open git diff in terminal" })

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd "autocmd! TermOpen term://* lua set_terminal_keymaps()"

-- Define a shortcut key to diff the current buffer with the release branch differences and display them in the terminal
vim.keymap.set("n", "\\fh", function()
  local utils = require "utils"
  local root = utils.find_root_dir()
  -- local cmd = "git diff release -- " .. root
  -- diff the current file with the release branch
  local cmd = "git diff release -- " .. vim.fn.expand "%:p"
  require("toggleterm").exec(cmd, 1, 12)
end, { desc = "file differences b" })

-- vim.keymap.set({ "n", "t" }, "<c-0>", function()
--   local utils = require "utils"
--   local root_dir = utils.find_root_dir()
--   if root_dir ~= nil then
--     vim.cmd("1ToggleTerm dir=" .. root_dir)
--     return
--   end
--   vim.cmd "1ToggleTerm "
-- end, { desc = "open terminal 1" })
--
-- vim.keymap.set({ "n", "t" }, "<c-9>", function()
--   local utils = require "utils"
--   local root_dir = utils.find_root_dir()
--   if root ~= nil then
--     vim.cmd("2ToggleTerm dir=" .. root_dir)
--     return
--   end
--   vim.cmd "2ToggleTerm"
-- end, { desc = "open terminal 2" })

-- 记录终端缓冲区的编号
-- TODO: Save the current window layout
local terminal_buffer_nr = nil
-- 定义一个函数来处理终端的打开和跳转
local function toggle_terminal()
  if terminal_buffer_nr and vim.api.nvim_buf_is_valid(terminal_buffer_nr) then
    -- 如果终端缓冲区存在且有效，跳转到该缓冲区
    -- Check how many windows are currently open
    local window_count = vim.api.nvim_list_wins()
    if #window_count > 1 then
      -- close other window and obtain current window
      vim.cmd "wincmd p"
      vim.cmd "hide"
    end
    vim.cmd("buffer " .. terminal_buffer_nr)
  else
    local window_count = vim.api.nvim_list_wins()
    if #window_count > 1 then
      -- close other window and obtain current window
      vim.cmd "wincmd p"
      vim.cmd "close"
    end
    -- 如果终端缓冲区不存在，创建一个新的终端缓冲区
    vim.cmd "enew" -- 创建一个新缓冲区
    vim.cmd "terminal" -- 在新缓冲区中打开终端
    terminal_buffer_nr = vim.api.nvim_get_current_buf() -- 记录当前终端缓冲区的编号
    print("new terminal " .. terminal_buffer_nr)
  end
end

require("toggleterm").setup {
  --  -- size can be a number or function which is passed the current terminal
  size = function(term)
    if term.direction == "horizontal" then
      return 10
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  on_open = function(term)
    vim.cmd "startinsert!"
    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
  end,
  open_mapping = [[<m-=>]],
  shade_terminals = true,
  insert_mappings = true, -- whether or not the open mapping applies in insert mode
  -- direction = "horizontal",
  direction = "horizontal",
  close_on_exit = true, -- close the terminal window when the process exits
  start_in_insert = true,
}

-- https://github.com/theopn/theovim/blob/main/lua/core.lua#L155
-- {{{ Terminal autocmd
-- Switch to insert mode when terminal is open
local term_augroup = vim.api.nvim_create_augroup("Terminal", { clear = true })
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
  -- TermOpen: for when terminal is opened for the first time
  -- BufEnter: when you navigate to an existing terminal buffer
  group = term_augroup,
  pattern = "term://*", --> only applicable for "BufEnter", an ignored Lua table key when evaluating TermOpen
  callback = function()
    -- insert
    vim.cmd "startinsert"
  end,
})
-- Automatically close terminal unless exit code isn't 0
vim.api.nvim_create_autocmd("TermClose", {
  group = term_augroup,
  callback = function()
    if vim.v.event.status == 0 then
      vim.api.nvim_buf_delete(0, {})
      vim.notify_once "Previous terminal job was successful!"
    else
      vim.notify_once "Error code detected in the current terminal job!"
    end
  end,
})
