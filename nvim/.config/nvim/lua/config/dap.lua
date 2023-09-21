local map = vim.keymap.set
-- https://github.com/ibhagwan/nvim-lua/blob/201b6e6eb27c9c05c7382e0cebd28cb1f849e826/lua/plugins/dap/init.lua
map({ "n", "v" }, "<F5>", "<cmd>lua require'dap'.continue()<CR>", { silent = true, desc = "DAP launch or continue" })
map({ "n", "v" }, "<F8>", "<cmd>lua require'dapui'.toggle()<CR>", { silent = true, desc = "DAP toggle UI" })
map(
  { "n", "v" },
  "<F9>",
  "<cmd>lua require'dap'.toggle_breakpoint()<CR>",
  { silent = true, desc = "DAP toggle breakpoint" }
)
map({ "n", "v" }, "<F10>", "<cmd>lua require'dap'.step_over()<CR>", { silent = true, desc = "DAP step over" })
map({ "n", "v" }, "<F11>", "<cmd>lua require'dap'.step_into()<CR>", { silent = true, desc = "DAP step into" })
map({ "n", "v" }, "<F12>", "<cmd>lua require'dap'.step_out()<CR>", { silent = true, desc = "DAP step out" })
map(
  { "n", "v" },
  "<leader>dc",
  "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
  { silent = true, desc = "set breakpoint with condition" }
)
map(
  { "n", "v" },
  "<leader>dp",
  "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>",
  { silent = true, desc = "set breakpoint with log point message" }
)
map(
  { "n", "v" },
  "<leader>dr",
  "<cmd>lua require'dap'.repl.toggle()<CR>",
  { silent = true, desc = "toggle debugger REPL" }
)

local dapui = require "dapui"
dapui.setup {
  layouts = {
    {
      position = "bottom",
      size = 10,
      elements = {
        { id = "repl", size = 0.50 },
        { id = "console", size = 0.50 },
      },
    },
    {
      position = "right",
      size = 40,
      elements = {
        { id = "scopes", size = 0.50 },
        { id = "stacks", size = 0.50 },
        { id = "breakpoints", size = 0.18 },
        { id = "watches", size = 0.25 },
      },
    },
  },
}

local dap = require "dap"

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end

dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

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
    callback { type = "server", host = "127.0.0.1", port = port }
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
  {
    type = "go",
    name = "Debug Package",
    request = "launch",
    program = "${fileDirname}",
  },
  {
    type = "go",
    name = "Attach",
    mode = "local",
    request = "attach",
    processId = require("dap.utils").pick_process,
  },
  {
    type = "go",
    name = "Debug test",
    request = "launch",
    mode = "test",
    program = "${file}",
  },
  {
    type = "go",
    name = "Debug test (go.mod)",
    request = "launch",
    mode = "test",
    program = "./${relativeFileDirname}",
  },
}

local uv = vim.loop

local nvim_server
local nvim_chanID

-- both deugging and execution is done on external headless instances
-- we start a headless instance and then call ("osv").launch() which
-- in turn starts another headless instance which will be the instance
-- we connect to
-- once the instance is running we can call `:luafile <file>` in order
-- to start debugging
local function dap_server(opts)
  assert(
    dap.adapters.nlua,
    "nvim-dap adapter configuration for nlua not found. " .. "Please refer to the README.md or :help osv.txt"
  )

  -- server already started?
  if nvim_chanID then
    local pid = vim.fn.jobpid(nvim_chanID)
    vim.fn.rpcnotify(nvim_chanID, "nvim_exec_lua", [[return require"osv".stop()]])
    vim.fn.jobstop(nvim_chanID)
    if type(uv.os_getpriority(pid)) == "number" then
      uv.kill(pid, 9)
    end
    nvim_chanID = nil
  end

  nvim_chanID = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless" }, { rpc = true })
  assert(nvim_chanID, "Could not create neovim instance with jobstart!")

  local mode = vim.fn.rpcrequest(nvim_chanID, "nvim_get_mode")
  assert(not mode.blocking, "Neovim is waiting for input at startup. Aborting.")

  -- make sure OSV is loaded
  vim.fn.rpcrequest(nvim_chanID, "nvim_command", "packadd one-small-step-for-vimkind")

  nvim_server = vim.fn.rpcrequest(nvim_chanID, "nvim_exec_lua", [[return require"osv".launch(...)]], { opts })

  vim.wait(100)

  -- print(("Server started on port %d, channel-id %d"):format(nvim_server.port, nvim_chanID))
  return nvim_server
end

dap.adapters.nlua = function(callback, config)
  if not config.port then
    local server = dap_server()
    config.host = server.host
    config.port = server.port
  end
  callback { type = "server", host = config.host, port = config.port }
  if type(config.post) == "function" then
    config.post()
  end
end

dap.configurations.lua = {
  {
    type = "nlua",
    name = "Debug current file",
    request = "attach",
    -- we acquire host/port in the adapters function above
    -- host = function() end,
    -- port = function() end,
    post = function()
      dap.listeners.after["setBreakpoints"]["osv"] = function(session, body)
        assert(nvim_chanID, "Fatal: neovim RPC channel is nil!")
        vim.fn.rpcnotify(nvim_chanID, "nvim_command", "luafile " .. vim.fn.expand "%:p")
        -- clear the lisener or we get called in any dap-config run
        dap.listeners.after["setBreakpoints"]["osv"] = nil
      end
      -- for k, v in pairs(dap.listeners.after) do
      --   v["test"] = function()
      --     print(k, "called")
      --   end
      -- end
    end,
  },
  {
    type = "nlua",
    request = "attach",
    name = "Attach to running Neovim instance",
    host = function()
      local value = vim.fn.input "Host [127.0.0.1]: "
      if value ~= "" then
        return value
      end
      return "127.0.0.1"
    end,
    port = function()
      local val = tonumber(vim.fn.input "Port: ")
      assert(val, "Please provide a port number")
      return val
    end,
  },
}
