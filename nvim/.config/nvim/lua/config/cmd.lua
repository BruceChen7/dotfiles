-- Terminal keymaps configuration
local utils = require "utils"

-- Test configurations
local TEST_CONFIG = {
  go = {
    tags = "integration_test,unit_test",
    gcflags = "all=-l",
    default_project = "luckyvideo",
  },
}

-- Zig test declaration detection
local function get_zig_test_declaration()
  local node = utils.treesitter.get_node_at_cursor()

  while node and node:type() ~= "TestDecl" do
    node = node:parent()
  end

  return node and node:type() == "TestDecl"
end

-- Test function validation
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

-- Project name resolution configurations
local project_mappings = {
  ecommerce = { project = "core", module = nil },
  ["knowledge-platform"] = { project = nil, module = "knowledgeplatform" },
  ["adminasynctask"] = { project = "chatbotcommon", module = "adminasynctask" },
  ["crm-proactive-push "] = { project = "crm", module = "proactivepush" },
  ["crm-proactive-task"] = { project = "crm", module = "proactivetask " },
  ["crm-main-service"] = { project = "crm", module = "crmmain" },
}

-- Helper function to find module from buffer path within app directory
local function find_module_in_app_dir(app_dir, buf_path)
  -- Strategy 1: Direct path resolution for buffers inside app/
  if buf_path:sub(1, #app_dir + 1) == app_dir .. "/" then
    local remainder = buf_path:sub(#app_dir + 2)
    return remainder:match "([^/]+)"
  end

  -- Strategy 2: Fallback by scanning app/ directories
  local entries = vim.fn.globpath(app_dir, "*", 0, 1)
  for _, entry in ipairs(entries) do
    if vim.fn.isdirectory(entry) == 1 then
      return entry:match "([^/]+)$"
    end
  end

  return nil
end

-- Project name resolution
-- Maps directory structure to Go test project and module names
local function get_project_name_by_root(root)
  -- Extract the last directory name from the root path
  local last_part = string.match(root, "([^/]+)$")
  local project_name = TEST_CONFIG.go.default_project
  local module_name = last_part

  -- Check predefined project mappings
  local mapping = project_mappings[last_part]
  if mapping then
    if mapping.project then
      project_name = mapping.project
    end
    if mapping.module then
      module_name = mapping.module
    end
  end

  -- Handle complex platform structure with app/ subdirectories
  if last_part == "platform" then
    local app_dir = root .. "/app"
    if vim.fn.isdirectory(app_dir) == 1 then
      local buf_path = vim.api.nvim_buf_get_name(0)
      local module_from_buffer = find_module_in_app_dir(app_dir, buf_path)

      -- Apply chatbotcommon project context if we successfully identified a module
      if module_from_buffer then
        project_name = "chatbotcommon"
        module_name = module_from_buffer
      end
    end
  end

  return project_name, module_name
end

-- Go test environment builder
local function get_go_test_env(project_name, module_name)
  if not utils.is_mac() or not utils.is_in_working_dir() then
    return ""
  end

  local cid = "global"
  if project_name == "chatbotcommon" then
    cid = "sg"
  end

  local env_parts = {
    "export env=test",
    string.format("export cid=%s", cid),
    string.format("export PROJECT_NAME=%s", project_name),
    "export DISABLE_PPROF=true",
    string.format("export MODULE_NAME=%s", module_name),
    "export SP_UNIX_SOCKET=/tmp/spex.sock",
    "export set_id=common",
  }
  return table.concat(env_parts, " && ")
end

-- Check if Go version is greater than 1.21
local function go_version_gt_1_21()
  local handle = io.popen "go version 2>/dev/null"
  if not handle then
    return false
  end
  local result = handle:read "*a"
  handle:close()

  local major, minor = result:match "go(%d+)%.(%d+)"
  if major and minor then
    major, minor = tonumber(major), tonumber(minor)
    return major > 1 or (major == 1 and minor > 21)
  end
  return false
end

-- Go test command builder
local function get_go_test_command(dir, function_name)
  local cwd = vim.fn.getcwd()
  local relative_path = utils.relative_path(cwd, dir)
  local go_executable = vim.fn.executable "xgo" == 1 and "xgo" or "go"
  local root = utils.find_root_dir()
  local project_name, module_name = get_project_name_by_root(root)
  local env_cmd = get_go_test_env(project_name, module_name)

  local ldflags = go_version_gt_1_21() and " -ldflags=--checklinkname=0" or ""
  local test_cmd = string.format(
    "%s test -count=1 ./%s -tags='%s' -gcflags=%s%s -v -run %s",
    go_executable,
    relative_path,
    TEST_CONFIG.go.tags,
    TEST_CONFIG.go.gcflags,
    ldflags,
    function_name
  )

  return env_cmd == "" and test_cmd or env_cmd .. " && " .. test_cmd
end

-- Test command dispatcher
local function get_test_command()
  vim.cmd "redraw"
  local buf_name = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local filetype = vim.bo.filetype

  local handlers = {
    zig = function()
      return get_zig_test_declaration() and string.format("cd %s && zig test %s", dir, buf_name)
    end,
    python = function()
      return string.format("cd %s && python3 -m unittest discover -s ./", dir)
    end,
    go = function()
      local function_name = utils.get_go_nearest_function()
      if not validate_test_function(function_name) then
        return nil
      end
      return get_go_test_command(dir, function_name)
    end,
  }

  local handler = handlers[filetype]
  return handler and handler()
end

-- SPEX configuration
local function get_spex_config()
  -- 如果 SP_UNIX_SOCKET 环境变量的值为空，那么不启动 SPEX 服务
  if os.getenv "SP_UNIX_SOCKET" == nil then
    return nil
  end
  if utils.is_m1_mac() then
    return { command = "socat -d -d -d UNIX-LISTEN:${SP_UNIX_SOCKET},reuseaddr,fork TCP:${SP_AGENT_DOMAIN}" }
  elseif utils.is_mac() then
    return {
      command = "inp-client --mode=forward --local_network=unix --local_address=/tmp/spex.sock --remote_network=unix --remote_address=/run/spex/spex.sock",
    }
  end
  return nil
end

-- SPEX job starter with error handling and status tracking
local spex_job_id = nil

-- Clean up SPEX job if it's still running
local function cleanup_spex_job()
  if spex_job_id and vim.fn.jobwait({ spex_job_id }, 0)[1] == -1 then
    vim.notify("Stopping SPEX job: " .. spex_job_id, vim.log.levels.DEBUG)
    vim.fn.jobstop(spex_job_id)
    spex_job_id = nil
  end
end

local function start_spex_job(config)
  -- Check if SPEX job is already running
  if spex_job_id and vim.fn.jobwait({ spex_job_id }, 0)[1] == -1 then
    vim.notify("SPEX job is already running", vim.log.levels.DEBUG)
    return spex_job_id
  end

  -- Start new SPEX job with proper error handling
  spex_job_id = vim.fn.jobstart(config.command, {
    on_stdout = function(_, data, _) end,
    on_stderr = function(_, data, _) end,
    on_exit = function(_, exit_code, _)
      spex_job_id = nil
    end,
  })

  if spex_job_id <= 0 then
    vim.notify("Failed to start SPEX job", vim.log.levels.ERROR)
    spex_job_id = nil
    return nil
  end

  vim.notify("SPEX job started with ID: " .. spex_job_id, vim.log.levels.DEBUG)
  return spex_job_id
end

-- Test command runner
local function run_test(cmd)
  vim.fn["asyncrun#run"]("", {
    mode = "async",
    raw = false,
    errorformat = "%.%# %trror: %m, %f:%l:%c: %m, %f:%l: %m, %f:%l:%c %m",
  }, cmd)
end

-- F2 keymap - run tests
vim.keymap.set("n", "<F2>", function()
  local cmd = get_test_command()
  if not cmd then
    return
  end

  local spex_config = get_spex_config()
  if spex_config then
    start_spex_job(spex_config)
  end

  utils.change_to_current_buffer_root_dir()
  run_test(cmd)
end, { desc = "open go test in quickfix" })

-- Build command handlers
local buildCommands = {
  go = {
    ["video/platform/app/shopconsole"] = "go build app/shopconsole/main.go",
    ["botapi"] = "go build cmd/main.go",
    ["coreapi"] = "go build app/chat-api/main.go",
    ["workbenchapi"] = "go build app/chat-api/main.go",
    ["bff"] = "make build-with-proto",
  },
}

-- Go build command builder
local function get_go_build_command()
  if not utils.is_in_working_dir() then
    return nil
  end

  local buf_path = vim.fn.expand "%:p"
  for pattern, cmd in pairs(buildCommands.go) do
    if string.find(buf_path, pattern, 1, true) then
      return cmd
    end
  end
end

-- Zig build command builder
local function get_zig_build_command()
  local buf_path = vim.fn.expand "%:p"

  -- Search for zig-redis directory
  local zig_redis_path = vim.fn.finddir("zigredis", buf_path .. ";")
  local start, _ = string.find(buf_path, "/zigredis")
  if start then
    vim.fn.chdir(zig_redis_path)
    return "zig build"
  end

  -- Search for zig-caskdb directory
  local zig_caskdb_path = vim.fn.finddir("zig%-caskdb", buf_path .. ";")
  start, _ = string.find(buf_path, "zig%-caskdb")
  if start then
    vim.fn.chdir(zig_caskdb_path)
    return "zig build"
  end
end

-- Build command dispatcher
local function get_build_command()
  local filetype = vim.bo.filetype
  if filetype == "go" then
    return get_go_build_command()
  end
  if filetype == "zig" then
    return get_zig_build_command()
  end
end

-- F5 keymap - build project
vim.keymap.set("n", "<F5>", function()
  local cmd = get_build_command()
  if not cmd then
    vim.notify("No build command found for current filetype", vim.log.levels.WARN)
    return
  end
  vim.notify(string.format("Building with: %s", cmd), vim.log.levels.INFO)
  vim.fn["asyncrun#run"]("", { mode = "async", raw = false, errorformat = "%f:%l:%c: %m" }, cmd)
end, { desc = "make build" })
