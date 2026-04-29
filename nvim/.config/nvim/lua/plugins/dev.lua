local pack = require "core.pack"
local gh = pack.github

local function setup_conform()
  require("conform").setup {
    formatters_by_ft = {
      lua = { "stylua" },
      go = { "gofmt", "goimports" },
      zig = { "zigfmt" },
      markdown = { "autocorrect", "trim_empty_lines" },
      typst = { "autocorrect" },
      python = { "ruff" },
      typescript = { "ts_fmt_script" },
      typescriptreact = { "ts_fmt_script" },
    },
    format_on_save = function()
      return { timeout_ms = 1000, lsp_fallback = true }
    end,
    formatters = {
      autocorrect = {
        command = "autocorrect",
        args = { "--stdin", "$FILENAME" },
      },
      trim_empty_lines = {
        command = "awk",
        args = {
          '/^$/{n=n RS}; /./{printf "%s%s%s",n,$0,RS; n=""}',
        },
      },
    },
  }

  local function read_package_json(root)
    local package_json = root .. "/package.json"
    if vim.fn.filereadable(package_json) ~= 1 then
      return nil
    end
    local ok_read, content = pcall(vim.fn.readfile, package_json)
    if not ok_read then
      return nil
    end
    local ok_decode, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
    if not ok_decode then
      return nil
    end
    return data
  end

  local function detect_package_manager(root, package_json)
    if package_json and package_json.packageManager then
      local name = package_json.packageManager:match "^(%w+)"
      if name == "pnpm" or name == "yarn" or name == "npm" then
        return name
      end
    end
    if vim.fn.filereadable(root .. "/pnpm-lock.yaml") == 1 then
      return "pnpm"
    end
    if vim.fn.filereadable(root .. "/yarn.lock") == 1 then
      return "yarn"
    end
    return "npm"
  end

  local function make_ts_fmt_formatter()
    return function(bufnr)
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == "" then
        return { command = "" }
      end
      local root = require("lspconfig.util").root_pattern("package.json")(filename)
      if not root then
        return { command = "" }
      end
      local package_json = read_package_json(root)
      local scripts = package_json and package_json.scripts or nil
      local script_name = scripts and (scripts.fmt and "fmt" or scripts.format and "format") or nil
      if not script_name then
        return { command = "" }
      end
      local package_manager = detect_package_manager(root, package_json)
      if package_manager == "pnpm" then
        return { command = "pnpm", args = { script_name }, cwd = root, stdin = false }
      end
      if package_manager == "yarn" then
        return { command = "yarn", args = { script_name }, cwd = root, stdin = false }
      end
      return { command = "npm", args = { "run", script_name }, cwd = root, stdin = false }
    end
  end

  local function make_go_formatter(cmd_name)
    return function(bufnr)
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename:match "%.pb%.go$" then
        return { command = "" }
      end
      return { command = cmd_name }
    end
  end

  require("conform").formatters.ts_fmt_script = make_ts_fmt_formatter()
  require("conform").formatters.gofmt = make_go_formatter "gofmt"
  require("conform").formatters.goimports = make_go_formatter "goimports"
end

local specs = {
  { src = gh "mfussenegger/nvim-dap" },
  { src = gh "igorlfs/nvim-dap-view" },
  { src = gh "theHamsta/nvim-dap-virtual-text" },
  { src = gh "Exafunction/codeium.vim" },
  { src = gh "stevearc/conform.nvim" },
  { src = gh "saecki/crates.nvim" },
  { src = gh "mrcjkb/rustaceanvim" },
  { src = gh "MunifTanjim/nui.nvim" },
  { src = gh "AndrewRadev/linediff.vim" },
  { src = gh "Goose97/timber.nvim" },
  { src = gh "skywind3000/vim-gutentags" },
  { src = gh "skywind3000/gutentags_plus" },
}

if vim.fn.executable "xmake" == 1 then
  table.insert(specs, { src = gh "Mythos-404/xmake.nvim" })
end

return {
  name = "dev",
  specs = specs,
  setup = function()
    pack.packadd "nvim-dap"
    pack.packadd "nvim-dap-view"
    pack.packadd "nvim-dap-virtual-text"
    pack.safe_require "config/dap"
    pack.load_on_event("InsertEnter", "codeium.vim", function()
      require "config/codeium"
    end)
    pack.packadd "conform.nvim"
    pack.packadd "rustaceanvim"
    pack.packadd "linediff.vim"
    pack.safe_call("conform", setup_conform)
    pack.safe_call("crates", function()
      pack.packadd "crates.nvim"
      require("crates").setup()
    end)
    pack.safe_call("xmake", function()
      if vim.fn.executable "xmake" == 0 then
        return
      end
      pack.packadd "xmake.nvim"
      require("xmake").setup()
    end)
    pack.safe_call("timber", function()
      pack.packadd "timber.nvim"
      require("timber").setup {}
    end)
    pack.packadd "gutentags_plus"
    pack.setup_config("vim-gutentags", "config/gtags")
  end,
}
