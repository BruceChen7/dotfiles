-- Terminal keymaps configuration
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
  local ts_utils = require "nvim-treesitter.ts_utils"
  local node = ts_utils.get_node_at_cursor()

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

-- Project name resolution
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

-- Go test environment builder
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

-- Go test command builder
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

-- Test command dispatcher
local function get_test_command()
  vim.api.nvim_command "redraw"
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
      local utils = require "utils"
      local function_name = utils.get_go_nearest_function()
      if not validate_test_function(function_name) then
        return nil
      end
      return build_go_test_command(utils, dir, function_name)
    end,
  }

  local handler = handlers[filetype]
  return handler and handler()
end

-- SPEX configuration
local function get_spex_config()
  local utils = require "utils"
  if utils.is_m1_mac() then
    return { command = "socat -d -d -d UNIX-LISTEN:${SP_UNIX_SOCKET},reuseaddr,fork TCP:${SP_AGENT_DOMAIN}" }
  elseif utils.is_mac() then
    return {
      command = "inp-client --mode=forward --local_network=unix --local_address=/tmp/spex.sock --remote_network=unix --remote_address=/run/spex/spex.sock",
    }
  end
  return nil
end

-- SPEX job starter
local function start_spex_job(config)
  vim.fn.jobstart(config.command, { on_stdout = function(_, _) end })
end

-- Test command runner
local function run_test_command(cmd)
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

  local utils = require "utils"
  local spex_config = get_spex_config()
  if spex_config then
    start_spex_job(spex_config)
  end

  utils.change_to_current_buffer_root_dir()
  run_test_command(cmd)
end, { desc = "open go test in quickfix" })

-- Build command handlers
local BUILD_COMMANDS = {
  go = {
    ["video/platform/app/shopconsole"] = "go build app/shopconsole/main.go",
    ["botapi"] = "go build cmd/main.go",
    ["coreapi"] = "go build app/chat-api/main.go",
    ["workbenchapi"] = "go build app/chat-api/main.go",
    ["bff"] = "make build-with-proto",
  },
}

-- Go build command builder
local function get_go_build_cmd()
  local utils = require "utils"
  if not utils.is_in_working_dir() then
    return nil
  end

  local buf_path = vim.fn.expand "%:p"
  for pattern, cmd in pairs(BUILD_COMMANDS.go) do
    if string.find(buf_path, pattern, 1, true) then
      return cmd
    end
  end
end

-- Zig build command builder
local function get_zig_build_cmd()
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
local function get_build_cmd()
  local filetype = vim.bo.filetype
  if filetype == "go" then
    return get_go_build_cmd()
  end
  if filetype == "zig" then
    return get_zig_build_cmd()
  end
end

-- F5 keymap - build project
vim.keymap.set("n", "<F5>", function()
  local cmd = get_build_cmd()
  print("cmd is", cmd)
  if not cmd then
    return
  end
  vim.fn["asyncrun#run"]("", { mode = "async", raw = false, errorformat = "%f:%l:%c: %m" }, cmd)
end, { desc = "make build" })

-- Terminal keymaps for git operations
local terminal_keymaps = {
  {
    "<leader>tl",
    function()
      local cmd = 'git log -p "' .. vim.fn.expand "%:p" .. '"'
      require("toggleterm").exec(cmd, 1, 12)
    end,
    "open git log for this file in terminal",
  },
  {
    "\\tf",
    function()
      local cmd = "git diff release -- " .. vim.fn.expand "%:p"
      require("toggleterm").exec(cmd, 1, 12)
    end,
    "open git log for this file in terminal",
  },
  {
    "\\tb",
    function()
      local current_file_path_with_name = vim.fn.expand "%:p"
      local cmd = "tig blame " .. current_file_path_with_name
      require("toggleterm").exec(cmd, 1, 12)
    end,
    "tig blame current file in terminal",
  },
  {
    "<leader>tt",
    function()
      local utils = require "utils"
      local root = utils.find_root_dir() or vim.fn.getcwd()
      local cmd = 'tig -C "' .. root .. '"'
      require("toggleterm").exec(cmd, 1, 12)
    end,
    "open tig",
  },
  {
    "\\gm",
    function()
      local utils = require "utils"
      local cmd = "git diff master -- " .. utils.find_root_dir()
      require("toggleterm").exec(cmd, 1, 12)
    end,
    "open git diff in terminal",
  },
  {
    "\\fh",
    function()
      local utils = require "utils"
      local cmd = "git diff release -- " .. vim.fn.expand "%:p"
      require("toggleterm").exec(cmd, 1, 12)
    end,
    "file differences b",
  },
}

-- Set terminal keymaps
for _, mapping in ipairs(terminal_keymaps) do
  vim.keymap.set("n", mapping[1], mapping[2], { desc = mapping[3] })
end

-- ToggleTerm configuration
require("toggleterm").setup {
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

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd "autocmd! TermOpen term://* lua set_terminal_keymaps()"

-- Remove <esc> mapping and add jj mapping for specified terminal filetypes
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "term://*",
  callback = function()
    local terminal_filetypes = { "sidekick_terminal", "snacks_terminal" }
    if vim.tbl_contains(terminal_filetypes, vim.bo.filetype) then
      vim.keymap.del("t", "<esc>", { buffer = 0 })
      vim.keymap.set("t", "jk", [[<C-\><C-n>]], { buffer = 0 })
    end
  end,
})

-- Terminal autocmds
local term_augroup = vim.api.nvim_create_augroup("Terminal", { clear = true })

-- Terminal insert mode handling
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
  group = term_augroup,
  pattern = "term://*",
  callback = function()
    vim.cmd "startinsert"
  end,
})

-- Terminal close handling
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
