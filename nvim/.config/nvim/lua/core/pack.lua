local M = {}

local group = vim.api.nvim_create_augroup("CorePack", { clear = true })

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "vim.pack" })
end

function M.github(repo)
  return "https://github.com/" .. repo
end

function M.packadd(name)
  local ok, err = pcall(vim.cmd.packadd, name)
  if not ok then
    notify("failed to load " .. name .. ": " .. err, vim.log.levels.WARN)
  end
  return ok
end

function M.safe_require(module)
  local ok, result = pcall(require, module)
  if not ok then
    notify("failed to require " .. module .. ": " .. result, vim.log.levels.WARN)
    return nil
  end
  return result
end

function M.setup_config(pack, module)
  M.packadd(pack)
  return M.safe_require(module)
end

function M.safe_call(label, callback)
  local ok, err = pcall(callback)
  if not ok then
    notify(label .. " failed: " .. err, vim.log.levels.WARN)
  end
  return ok
end

function M.user_command(name, pack, callback, opts)
  opts = opts or {}
  vim.api.nvim_create_user_command(name, function(args)
    M.packadd(pack)
    callback(args)
  end, opts)
end

function M.load_on_filetype(filetypes, pack, callback)
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = filetypes,
    callback = function()
      M.packadd(pack)
      if callback then
        M.safe_call("setup " .. pack, callback)
      end
    end,
  })
end

function M.load_on_event(events, pack, callback)
  vim.api.nvim_create_autocmd(events, {
    group = group,
    once = true,
    callback = function()
      M.packadd(pack)
      if callback then
        M.safe_call("setup " .. pack, callback)
      end
    end,
  })
end

local function run(command)
  vim.system(command, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        notify(table.concat(command, " ") .. " failed", vim.log.levels.WARN)
      end)
    end
  end)
end

local function plugin_name(spec)
  if spec.name then
    return spec.name
  end
  return spec.src:match "([^/]+)$"
end

function M.setup_build_hooks()
  vim.api.nvim_create_autocmd("PackChanged", {
    group = group,
    callback = function(event)
      local kind = event.data and event.data.kind
      if kind ~= "install" and kind ~= "update" then
        return
      end

      local spec = event.data.spec or {}
      if spec.name == "blink.cmp" then
        run { "cargo", "build", "--release", "--manifest-path", event.data.path .. "/Cargo.toml" }
      elseif spec.name == "nvim-treesitter" then
        vim.schedule(function()
          pcall(vim.cmd, "TSUpdate")
        end)
      elseif spec.name == "tree-sitter-d2" then
        run { "make", "-C", event.data.path, "nvim-install" }
      elseif spec.name == "catppuccin" then
        vim.schedule(function()
          pcall(vim.cmd.CatppuccinCompile)
        end)
      end
    end,
  })
end

function M.setup(modules)
  if not vim.pack then
    notify("Neovim 0.12+ is required for vim.pack", vim.log.levels.ERROR)
    return
  end

  M.setup_build_hooks()

  local specs = {}
  local seen = {}
  for _, module in ipairs(modules) do
    for _, spec in ipairs(module.specs or {}) do
      local name = plugin_name(spec)
      if not seen[name] then
        seen[name] = true
        table.insert(specs, spec)
      end
    end
  end

  if vim.env.NVIM_SKIP_PACK_INSTALL ~= "1" then
    local ok, err = pcall(vim.pack.add, specs, { confirm = false, load = false })
    if not ok then
      notify("install/update failed: " .. err, vim.log.levels.WARN)
    end
  end

  for _, module in ipairs(modules) do
    if module.setup then
      M.safe_call(module.name or "plugin module", module.setup)
    end
  end
end

return M
