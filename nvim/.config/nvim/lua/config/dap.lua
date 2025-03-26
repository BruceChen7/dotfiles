local map = vim.keymap.set
-- https://github.com/ibhagwan/nvim-lua/blob/201b6e6eb27c9c05c7382e0cebd28cb1f849e826/lua/plugins/dap/init.lua
map({ "n", "v" }, "<F7>", "<cmd>lua require'dap'.continue()<CR>", { silent = true, desc = "DAP launch or continue" })
map(
  { "n", "v" },
  "\\db",
  "<cmd>lua require'dap'.toggle_breakpoint()<CR>",
  { silent = true, desc = "DAP toggle breakpoint" }
)
map({ "n", "v" }, "<F10>", "<cmd>lua require'dap'.step_over()<CR>", { silent = true, desc = "DAP step over" })
map({ "n", "v" }, "<F8>", "<cmd>lua require'dap'.step_into()<CR>", { silent = true, desc = "DAP step into" })
map({ "n", "v" }, "<F9>", "<cmd>lua require'dap'.step_out()<CR>", { silent = true, desc = "DAP step out" })
map(
  { "n", "v" },
  "<leader>dr",
  "<cmd>lua require'dap'.repl.toggle()<CR>",
  { silent = true, desc = "toggle debugger REPL" }
)

local dap = require "dap"
dap.set_log_level "TRACE"
vim.keymap.set("n", "\\gb", dap.run_to_cursor, { silent = true, desc = "DAP run to cursor" })

-- require("dap").defaults.fallback.switchbuf = "useopen"
require("dap-view").setup {}

require("nvim-dap-virtual-text").setup()

map({ "n", "v" }, "\\dv", function()
  require("dap-view").toggle()
end, { silent = true, desc = "DAP viewer toggle" })

dap.listeners.before.attach.dapui_config = function()
  vim.cmd "DapViewOpen"
end
dap.listeners.before.launch.dapui_config = function()
  vim.cmd "DapViewOpen"
end
dap.listeners.before.event_terminated.dapui_config = function()
  vim.cmd "DapViewClose"
end
dap.listeners.before.event_exited.dapui_config = function()
  vim.cmd "DapViewClose"
end

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "dap-view", "dap-view-term", "dap-repl" }, -- dap-repl is set by `nvim-dap`
  callback = function(evt)
    vim.keymap.set("n", "q", "<C-w>q", { silent = true, buffer = evt.buf })
  end,
})

-- DAP-Client ----- Debug Adapter ------- Debugger ------ Debugee
-- (nvim-dap)  |   (per language)  |   (per language)    (your app)
--             |                   |
--             |        Implementation specific communication
--             |        Debug adapter and debugger could be the same process
--             |
--      Communication via the Debug Adapter Protocol
--  配置debug adapter
-- `dap.adapters.<name>` can also be set to a function which takes three arguments:
-- The |dap-configuration| which the user wants to use.
-- An optional parent session. This is only available if the debug-adapter
-- 这里设置的是debug adapter的配置
local dap = require "dap"

dap.adapters.go = function(callback, config)
  local stdout = vim.loop.new_pipe(false)
  local handle
  local pid_or_err
  -- 指定端口信息
  local host = config.host or "127.0.0.1"
  local port = config.port or "38697"
  local addr = string.format("%s:%s", host, port)
  local opts = {
    stdio = { nil, stdout },
    args = { "dap", "-l", addr },
    detached = true,
  }

  -- 使用`dlv`（Go的调试工具）作为调试适配器。
  -- 启动`dlv`进程，并设置其监听地址和端口（默认为`127.0.0.1:38697`）。
  handle, pid_or_err = vim.loop.spawn("dlv", opts, function(code)
    stdout:close()
    handle:close()
    if code ~= 0 then
      print("dlv exited with code", code)
    end
  end)
  assert(handle, "Error running dlv: " .. tostring(pid_or_err))
  stdout:read_start(function(err, chunk)
    assert(not err, err)
    if chunk then
      vim.schedule(function()
        -- 执行repl的逻辑
        require("dap.repl").append(chunk)
      end)
    end
  end)
  -- Wait for delve to start

  vim.defer_fn(function()
    callback { type = "server", host = host, port = port }
  end, 100)
end

-- type: string        -- Which debug adapter to use.
-- request: string     -- Either `attach` or `launch`. Indicates whether the debug adapter should launch a debugee or attach to one that is already running.
-- name: string        -- A user-readable name for the configuration.
-- - Some variables are supported:
-- - `${file}`: Active filename
-- - `${fileBasename}`: The current file's basename
-- - `${fileBasenameNoExtension}`: The current file's basename without extension
-- - `${fileDirname}`: The current file's dirname
-- - `${fileExtname}`: The current file's extension
-- - `${relativeFile}`: The current file relative to |getcwd()|
-- - `${relativeFileDirname}`: The current file's dirname relative to |getcwd()|
-- - `${workspaceFolder}`: The current working directory of Neovim
-- - `${workspaceFolderBasename}`: The name of the folder opened in Neovim
-- - `${command:pickProcess}`: Open dialog to pick process using |vim.ui.select|
-- - `${env:Name}`: Environment variable named `Name`, for example: `${env:HOME}`.
dap.configurations.go = {
  {
    type = "go",
    name = "Debug",
    request = "launch",
    program = "${file}",
  },
}
--

vim.keymap.set("n", "<F6>", function()
  local utils = require "utils"
  local cwd = vim.fn.getcwd()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local testpath = utils.relative_path(cwd, dir)
  local go_ts = require "utils"
  local testname = go_ts.get_go_nearest_function()
  if testname == nil then
    print "testname is nil"
    return
  end

  print("testname is " .. testname)
  print("relative_path is " .. testpath)

  local build_flags = "-tags='integration_test,unit_test' -gcflags=all=-l"
  local config = {
    type = "go",
    name = testname,
    request = "launch",
    mode = "test",
    program = testpath,
    args = { "-test.run", "^" .. testname .. "$" },
    buildFlags = build_flags,
  }
  print(vim.inspect(config))
  local dap = require "dap"
  dap.run(config)
end, { silent = true, desc = "debug test case" })
