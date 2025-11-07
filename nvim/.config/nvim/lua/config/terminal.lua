-- Terminal keymaps configuration
local utils = require "utils"
local toggleterm = require "toggleterm"

_G.set_terminal_keymaps = function()
  local opts = { buffer = 0 }
  -- using <esc> to enter normal mode
  -- vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
  vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
  vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
  vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end

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

-- Go test command builder
local function get_go_test_command(dir, function_name)
  local cwd = vim.fn.getcwd()
  local relative_path = utils.relative_path(cwd, dir)
  local go_executable = vim.fn.executable "xgo" == 1 and "xgo" or "go"
  local root = utils.find_root_dir()
  local project_name, module_name = get_project_name_by_root(root)
  local env_cmd = get_go_test_env(project_name, module_name)

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
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        vim.notify("SPEX: " .. table.concat(data, "\n"), vim.log.levels.DEBUG)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        vim.notify("SPEX Error: " .. table.concat(data, "\n"), vim.log.levels.WARN)
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        vim.notify(string.format("SPEX job exited with code: %d", exit_code), vim.log.levels.ERROR)
      else
        vim.notify("SPEX job completed successfully", vim.log.levels.DEBUG)
      end
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

-- Helper function to get the default branch (release -> master -> main)
-- @return string: The branch name to use for diff operations
local function get_default_branch()
  local branches = vim.fn.systemlist "git branch -a"
  if vim.v.shell_error ~= 0 then
    return "main" -- fallback if not in a git repo
  end

  -- Check branches in priority order: release -> master -> main
  local priority = { "release", "master", "main" }
  for _, target in ipairs(priority) do
    for _, branch in ipairs(branches) do
      if branch:match("^%s*" .. target .. "$") or branch:match("remotes/origin/" .. target .. "$") then
        return target
      end
    end
  end

  -- Default to main if no matches found
  return "main"
end

-- Helper function to get terminal keymap handler
-- @param cmd_template string: Command template with placeholders (%:p for file path, %:root for root dir, %:branch for default branch)
-- @param opts table: Optional configuration { use_root = boolean }
local function get_terminal_handler(cmd_template, opts)
  opts = opts or {}
  return function()
    local cmd = cmd_template:gsub("%%:p", vim.fn.expand "%:p")
    if opts.use_root then
      cmd = cmd:gsub("%%:root", utils.find_root_dir() or vim.fn.getcwd())
    end
    cmd = cmd:gsub("%%:branch", get_default_branch())
    toggleterm.exec(cmd, 1, 12)
  end
end

-- Terminal keymaps for git operations
local terminal_keymaps = {
  {
    "<leader>tl",
    get_terminal_handler 'git log -p "%:p"',
    desc = "open git log for this file in terminal",
  },
  {
    "\\tf",
    get_terminal_handler "git diff %:branch -- %:p",
    desc = "open git diff for this file in terminal",
  },
  {
    "\\tb",
    get_terminal_handler "tig blame %:p",
    desc = "tig blame current file in terminal",
  },
  {
    "<leader>tt",
    get_terminal_handler('tig -C "%:root"', { use_root = true }),
    desc = "open tig",
  },
  {
    "\\gm",
    get_terminal_handler("git diff %:branch -- %:root", { use_root = true }),
    desc = "open git diff in terminal",
  },
  {
    "\\fh",
    get_terminal_handler "git diff %:branch -- %:p",
    desc = "file differences",
  },
}

-- Set terminal keymaps using utility function
utils.register_keymaps(terminal_keymaps)

-- ToggleTerm configuration
toggleterm.setup {
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
  insert_mappings = true,
  direction = "horizontal",
  close_on_exit = true,
  start_in_insert = true,
}

-- Terminal autocmds
local term_augroup = vim.api.nvim_create_augroup("Terminal", { clear = true })

-- Define autocmds in a single table for better organization
local terminal_autocmds = {
  -- Set terminal keymaps and handle special filetypes
  {
    event = "TermOpen",
    pattern = "term://*",
    callback = function()
      -- Set common terminal keymaps
      set_terminal_keymaps()

      -- For specific terminal types, use jk instead of <esc>
      local terminal_filetypes = { "sidekick_terminal", "snacks_terminal" }
      if vim.tbl_contains(terminal_filetypes, vim.bo.filetype) then
        vim.keymap.del("t", "<esc>", { buffer = 0 })
        vim.keymap.set("t", "jk", [[<C-\><C-n>]], { buffer = 0 })
      end
    end,
  },
  {
    event = { "TermOpen", "BufEnter" },
    pattern = "term://*",
    callback = function()
      vim.cmd "startinsert"
    end,
  },
  {
    event = { "TermClose" },
    pattern = "term://*",
    callback = function()
      if vim.v.event.status == 0 then
        vim.api.nvim_buf_delete(0, {})
        vim.notify_once "Previous terminal job was successful!"
      else
        vim.notify_once "Error code detected in the current terminal job!"
      end
    end,
  },
}

-- Create all autocmds at once
for _, autocmd in ipairs(terminal_autocmds) do
  vim.api.nvim_create_autocmd(autocmd.event, {
    group = term_augroup,
    pattern = autocmd.pattern,
    callback = autocmd.callback,
  })
end

-- Clean up SPEX job when Neovim exits
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = term_augroup,
  callback = cleanup_spex_job,
  desc = "Clean up SPEX job on exit",
})
