--- LSP Proxy for Pi CR codediff virtual buffers
---
--- codediff deliberately prevents LSP on its virtual buffers (codediff:// URIs)
--- because LSP servers can't handle custom URI schemes and crash or misbehave.
---
--- This module creates hidden "proxy" buffers with real file paths, attaches LSP
--- to them, and redirects LSP operations from the codediff view buffers through
--- the proxy buffers using `nvim_buf_call` + Neovim's built-in LSP functions.
---
--- Architecture:
---
---   codediff buffer (codediff://.../src/foo.go)    proxy buffer (/path/to/src/foo.go)
---     │  LSP: ✗                                        LSP: ✓
---     │                                                 │
---     └── nvim_buf_call(proxy, vim.lsp.buf.definition) ─┘
---         (built-in LSP handles jumplist, tagstack, everything)
---
--- Two codediff panels (original + modified) for the same file share a SINGLE
--- proxy buffer.  Content is synced on-demand before each LSP operation.

local M = {}

--- @type table<codediff_bufnr, {proxy_bufnr: number, real_path: string, reused_existing: boolean}>
local codediff_to_proxy = {}

local function log(fmt, ...)
  vim.notify(string.format(fmt, ...), vim.log.levels.DEBUG, { title = "Pi CR LSP" })
end

-- Detect Snacks picker availability (lazy-loaded)
local function try_snacks(fn_name)
  local ok, snacks = pcall(require, "snacks.picker")
  if ok then
    return snacks[fn_name]
  end
  return nil
end

--------------------------------------------------------------------------------
--- URL parsing
--------------------------------------------------------------------------------

local function parse_url(url)
  local patterns = {
    "^codediff:///(.-)///([a-fA-F0-9]+)/(.+)$",
    "^codediff:///(.-)///([a-fA-F0-9]+%^)/(.+)$",
    "^codediff:///(.-)///([A-Za-z][A-Za-z0-9_~^%%%-]*)/(.+)$",
    "^codediff:///(.-)///(:[0-9]:?)/(.+)$",
  }
  for _, p in ipairs(patterns) do
    local g, c, f = url:match(p)
    if g then
      return { git_root = g, commit = c, filepath = f }
    end
  end
  return nil
end

local function is_codediff_buf(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr)
    and vim.api.nvim_buf_get_name(bufnr):find("^codediff://") == 1
end

--------------------------------------------------------------------------------
--- Proxy buffer lifecycle
--------------------------------------------------------------------------------

function M.get_proxy(codediff_bufnr)
  local entry = codediff_to_proxy[codediff_bufnr]
  if not entry then
    return nil
  end
  if not vim.api.nvim_buf_is_valid(entry.proxy_bufnr) then
    codediff_to_proxy[codediff_bufnr] = nil
    return nil
  end
  return entry.proxy_bufnr
end

local function sync_content(codediff_bufnr)
  local entry = codediff_to_proxy[codediff_bufnr]
  if not entry or not vim.api.nvim_buf_is_valid(entry.proxy_bufnr) then
    return
  end
  if not vim.api.nvim_buf_is_valid(codediff_bufnr) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(codediff_bufnr, 0, -1, false)
  pcall(vim.api.nvim_buf_set_lines, entry.proxy_bufnr, 0, -1, false, lines)
end

--- Create a proxy buffer for a codediff buffer.
---
--- Two codediff panels for the same real_path share a SINGLE proxy buffer.
--- Content is synced on-demand before each LSP request.
local function create_proxy(codediff_bufnr)
  local name = vim.api.nvim_buf_get_name(codediff_bufnr)
  local info = parse_url(name)
  if not info then
    return nil
  end

  local real_path = info.git_root .. "/" .. info.filepath

  if codediff_to_proxy[codediff_bufnr] then
    return codediff_to_proxy[codediff_bufnr].proxy_bufnr
  end

  -- Check if another codediff buffer already created a proxy for this real_path.
  for _, entry in pairs(codediff_to_proxy) do
    if entry.real_path == real_path and vim.api.nvim_buf_is_valid(entry.proxy_bufnr) then
      codediff_to_proxy[codediff_bufnr] = {
        proxy_bufnr = entry.proxy_bufnr,
        real_path = real_path,
        reused_existing = true,
      }
      M.setup_keymaps(codediff_bufnr)
      log("Shared proxy %d for %s", entry.proxy_bufnr, info.filepath)
      return entry.proxy_bufnr
    end
  end

  -- First buffer for this real_path: create a new proxy.
  local proxy_bufnr = vim.api.nvim_create_buf(false, false)
  pcall(vim.api.nvim_buf_set_name, proxy_bufnr, real_path)

  local lines = vim.api.nvim_buf_get_lines(codediff_bufnr, 0, -1, false)
  pcall(vim.api.nvim_buf_set_lines, proxy_bufnr, 0, -1, false, lines)

  vim.bo[proxy_bufnr].bufhidden = "hide"
  vim.bo[proxy_bufnr].modified = false

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("PiCRLspBuf_" .. proxy_bufnr, { clear = true }),
    buffer = proxy_bufnr,
    once = true,
    callback = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(proxy_bufnr) then
          return
        end
        vim.bo[proxy_bufnr].buftype = "nofile"
        log("LSP attached to proxy %d, set buftype=nofile", proxy_bufnr)
      end)
    end,
  })

  local ft = vim.filetype.match({ buf = proxy_bufnr, filename = info.filepath })
  if ft then
    vim.bo[proxy_bufnr].filetype = ft
    log("Filetype=%s set on proxy %d for %s", ft, proxy_bufnr, info.filepath)
  end

  codediff_to_proxy[codediff_bufnr] = {
    proxy_bufnr = proxy_bufnr,
    real_path = real_path,
    reused_existing = false,
  }
  log("Created proxy %d for %s (commit=%s)", proxy_bufnr, info.filepath, info.commit)
  return proxy_bufnr
end

--------------------------------------------------------------------------------
--- LSP operation wrappers (nvim_buf_call + Neovim built-in LSP)
--------------------------------------------------------------------------------

---@param codediff_bufnr number
---@param fn fun()
---@return boolean true if proxy available and LSP is attached
local function with_proxy(codediff_bufnr, fn)
  local proxy = M.get_proxy(codediff_bufnr)
  if not proxy then
    return false
  end
  sync_content(codediff_bufnr)
  local clients = vim.lsp.get_clients({ bufnr = proxy })
  if #clients == 0 then
    return false
  end
  fn(proxy)
  return true
end

---@param fn fun(proxy: number)  receives proxy bufnr to use in nvim_buf_call
local function with_current_proxy(fn)
  return with_proxy(vim.api.nvim_get_current_buf(), fn)
end

function M.hover()
  with_current_proxy(function(proxy)
    -- vim.lsp.buf.hover() reads the window's buffer for the URI —
    -- briefly swap the proxy into the window so the URI is correct.
    local orig_buf = vim.api.nvim_win_get_buf(0)
    vim.api.nvim_win_set_buf(0, proxy)
    vim.api.nvim_buf_call(proxy, function()
      vim.lsp.buf.hover()
    end)
    vim.api.nvim_win_set_buf(0, orig_buf)
  end)
end

function M.definition()
  with_current_proxy(function(proxy)
    local fn = try_snacks("lsp_definitions")
    if fn then
      -- Snacks picker needs a real window; briefly swap proxy in
      local orig_buf = vim.api.nvim_win_get_buf(0)
      vim.api.nvim_win_set_buf(0, proxy)
      fn()
      vim.api.nvim_win_set_buf(0, orig_buf)
    else
      vim.api.nvim_buf_call(proxy, vim.lsp.buf.definition)
    end
  end)
end

function M.references()
  with_current_proxy(function(proxy)
    local fn = try_snacks("lsp_references")
    if fn then
      local orig_buf = vim.api.nvim_win_get_buf(0)
      vim.api.nvim_win_set_buf(0, proxy)
      fn()
      vim.api.nvim_win_set_buf(0, orig_buf)
    else
      vim.api.nvim_buf_call(proxy, vim.lsp.buf.references)
    end
  end)
end

function M.declaration()
  with_current_proxy(function(proxy)
    local fn = try_snacks("lsp_declarations")
    if fn then
      local orig_buf = vim.api.nvim_win_get_buf(0)
      vim.api.nvim_win_set_buf(0, proxy)
      fn()
      vim.api.nvim_win_set_buf(0, orig_buf)
    else
      vim.api.nvim_buf_call(proxy, vim.lsp.buf.declaration)
    end
  end)
end

function M.implementation()
  with_current_proxy(function(proxy)
    local fn = try_snacks("lsp_implementations")
    if fn then
      local orig_buf = vim.api.nvim_win_get_buf(0)
      vim.api.nvim_win_set_buf(0, proxy)
      fn()
      vim.api.nvim_win_set_buf(0, orig_buf)
    else
      vim.api.nvim_buf_call(proxy, vim.lsp.buf.implementation)
    end
  end)
end

function M.type_definition()
  with_current_proxy(function(proxy)
    local fn = try_snacks("lsp_type_definitions")
    if fn then
      local orig_buf = vim.api.nvim_win_get_buf(0)
      vim.api.nvim_win_set_buf(0, proxy)
      fn()
      vim.api.nvim_win_set_buf(0, orig_buf)
    else
      vim.api.nvim_buf_call(proxy, vim.lsp.buf.type_definition)
    end
  end)
end

function M.incoming_calls()
  with_current_proxy(function(proxy)
    vim.api.nvim_buf_call(proxy, vim.lsp.buf.incoming_calls)
  end)
end

function M.outgoing_calls()
  with_current_proxy(function(proxy)
    vim.api.nvim_buf_call(proxy, vim.lsp.buf.outgoing_calls)
  end)
end

function M.rename()
  with_current_proxy(function(proxy)
    vim.api.nvim_buf_call(proxy, vim.lsp.buf.rename)
  end)
end

function M.code_action()
  with_current_proxy(function(proxy)
    -- Briefly swap the proxy into the window for correct URI
    local orig_buf = vim.api.nvim_win_get_buf(0)
    vim.api.nvim_win_set_buf(0, proxy)
    vim.api.nvim_buf_call(proxy, vim.lsp.buf.code_action)
    vim.api.nvim_win_set_buf(0, orig_buf)
  end)
end

--------------------------------------------------------------------------------
--- Keymap setup
--------------------------------------------------------------------------------

function M.setup_keymaps(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local function map(mode, lhs, rhs, desc)
    pcall(vim.keymap.set, mode, lhs, rhs, {
      buffer = bufnr,
      silent = true,
      desc = desc,
    })
  end

  map("n", "K", function()
    local winid = require("ufo").peekFoldedLinesUnderCursor()
    if winid then return end
    local cr_ok, cr = pcall(require, "pi.cr")
    if cr_ok and cr.show_annotation_under_cursor and cr.show_annotation_under_cursor() then return end
    M.hover()
  end, "Peek Fold / CR Annotation / LSP Hover (via proxy)")

  map("n", "gd", M.definition, "LSP Definition (via proxy)")
  map("n", "grr", M.references, "LSP References (via proxy)")
  map("n", "gD", M.declaration, "LSP Declaration (via proxy)")
  map("n", "\\gi", M.implementation, "LSP Implementation (via proxy)")
  map("n", "\\gy", M.type_definition, "LSP Type Definition (via proxy)")
  map("n", "<leader>li", M.incoming_calls, "LSP Incoming Calls (via proxy)")
  map("n", "<leader>lo", M.outgoing_calls, "LSP Outgoing Calls (via proxy)")
  map("n", "<leader>lr", M.rename, "LSP Rename (via proxy)")
  map({ "n", "x" }, "<leader>ca", M.code_action, "LSP Code Action (via proxy)")

  log("Keymaps installed on bufnr=%d", bufnr)
end

--------------------------------------------------------------------------------
--- Cleanup
--------------------------------------------------------------------------------

function M.cleanup(codediff_bufnr)
  local entry = codediff_to_proxy[codediff_bufnr]
  if not entry then
    return
  end
  if not entry.reused_existing
    and vim.api.nvim_buf_is_valid(entry.proxy_bufnr)
    and #vim.fn.win_findbuf(entry.proxy_bufnr) == 0
  then
    pcall(vim.api.nvim_buf_delete, entry.proxy_bufnr, { force = true })
  end
  codediff_to_proxy[codediff_bufnr] = nil
end

local function cleanup_all()
  for bufnr, _ in pairs(codediff_to_proxy) do
    M.cleanup(bufnr)
  end
end

--------------------------------------------------------------------------------
--- Event handlers
--------------------------------------------------------------------------------

local function on_virtual_file_loaded(data)
  local bufnr = data and data.buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not is_codediff_buf(bufnr) then
    return
  end

  vim.schedule(function()
    local proxy = create_proxy(bufnr)
    if proxy then
      M.setup_keymaps(bufnr)
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("PiCRLspProxy", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeDiffVirtualFileLoaded",
    callback = function(args)
      on_virtual_file_loaded(args.data)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeDiffClose",
    callback = function()
      vim.schedule(cleanup_all)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    pattern = "codediff://*",
    callback = function(args)
      M.cleanup(args.buf)
    end,
  })
end

return M
