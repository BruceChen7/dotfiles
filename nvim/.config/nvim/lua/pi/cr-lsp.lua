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
  -- Only emit proxy LSP debug messages when PI_CR_LSP_DEBUG is set.
  -- vim.notify() writes to the message area and causes stuttering in diff views.
  if vim.env.PI_CR_LSP_DEBUG then
    vim.notify(string.format(fmt, ...), vim.log.levels.DEBUG, { title = "Pi CR LSP" })
  end
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
  return vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr):find "^codediff://" == 1
end

local function synthetic_proxy_path(real_path, codediff_bufnr)
  local dir = vim.fs.dirname(real_path)
  local base = vim.fs.basename(real_path)
  local stem = base
  local ext = ""
  local idx = base:match "^.*()%.([^.]*)$"
  if idx then
    stem = base:sub(1, idx - 1)
    ext = base:sub(idx)
  end

  return string.format("%s/.pi_cr_lsp__%d__%s%s", dir, codediff_bufnr, stem, ext)
end

local function proxy_path_for_real_path(real_path, codediff_bufnr)
  -- Never name the proxy buffer as the real file. In a CodeDiff view the real
  -- file is often already open on the modified side; `nvim_buf_set_name` then
  -- fails, leaving an unnamed proxy. tsgo can attach to that unnamed buffer and
  -- crash while resolving a relative "tsconfig.json". A synthetic absolute
  -- path in the same directory keeps root discovery/import resolution working
  -- without colliding with the real file buffer.
  return synthetic_proxy_path(real_path, codediff_bufnr)
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

--- Get first LSP client + proxy for the current codediff buffer.
--- Syncs proxy content before returning so cursor/offset math matches.
--- @return table|nil, number|nil
local function get_lsp_client()
  local bufnr = vim.api.nvim_get_current_buf()
  local proxy = M.get_proxy(bufnr)
  if not proxy then
    return nil, nil
  end

  sync_content(bufnr)

  local clients = vim.lsp.get_clients { bufnr = proxy }
  if #clients == 0 then
    return nil, proxy
  end
  return clients[1], proxy
end

--- Build textDocument/position using proxy URI + current window cursor.
--- @param client table
--- @param proxy_bufnr number
--- @return table
local function make_position_params(client, proxy_bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local offenc = client.offset_encoding or "utf-16"
  local row = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(proxy_bufnr, row, row + 1, false)[1] or ""
  if col > 0 then
    col = vim.str_utfindex(line, offenc, col, false)
  end
  return {
    textDocument = { uri = vim.uri_from_bufnr(proxy_bufnr) },
    position = { line = row, character = col },
  }
end

---@class PiCrLspLocationMatch
---@field location table
---@field offset_encoding string

--- Open a single target or quickfix for multiple.
---@param matches PiCrLspLocationMatch[]
---@param opts? {always_list?: boolean}
local function handle_location_matches(matches, opts)
  opts = opts or {}
  if not matches or #matches == 0 then
    return
  end
  if #matches == 1 and not opts.always_list then
    local origin_buf = vim.api.nvim_get_current_buf()
    local match = matches[1]
    local loc = match.location
    local uri = loc.uri or loc.targetUri
    if not uri then
      return
    end
    local bufnr = vim.uri_to_bufnr(uri)
    if bufnr == 0 then
      return
    end
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local range = loc.range or loc.targetSelectionRange

    -- codediff virtual buffers use bufhidden=wipe. If we replace the window via
    -- :edit, the source codediff buffer gets destroyed immediately, so Ctrl-O
    -- has nowhere to return. Preserve it as hidden, then restore wipe when the
    -- user lands back in that buffer.
    if vim.api.nvim_buf_is_valid(origin_buf) and vim.bo[origin_buf].bufhidden == "wipe" then
      vim.bo[origin_buf].bufhidden = "hide"
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("PiCRRestoreBufhidden_" .. origin_buf, { clear = true }),
        buffer = origin_buf,
        once = true,
        callback = function()
          if vim.api.nvim_buf_is_valid(origin_buf) then
            vim.bo[origin_buf].bufhidden = "wipe"
          end
        end,
      })
    end

    if range then
      local p = vim.pos.lsp(bufnr, range.start, match.offset_encoding)
      vim.cmd("edit +" .. (p.row + 1) .. " " .. vim.fn.fnameescape(fname))
      vim.api.nvim_win_set_cursor(0, { p.row + 1, p.col })
    else
      vim.cmd("edit " .. vim.fn.fnameescape(fname))
    end
    vim.cmd "normal! zz"
  else
    local items = {}
    for _, match in ipairs(matches) do
      vim.list_extend(items, vim.lsp.util.locations_to_items({ match.location }, match.offset_encoding))
    end
    vim.fn.setqflist({}, " ", { title = "LSP Locations", items = items })
    vim.cmd "copen"
  end
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
  local proxy_path = proxy_path_for_real_path(real_path, codediff_bufnr)

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
  local named, name_err = pcall(vim.api.nvim_buf_set_name, proxy_bufnr, proxy_path)
  if not named then
    pcall(vim.api.nvim_buf_delete, proxy_bufnr, { force = true })
    vim.notify(
      string.format("Failed to name CR LSP proxy %s: %s", proxy_path, name_err),
      vim.log.levels.ERROR,
      { title = "Pi CR LSP" }
    )
    return nil
  end

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

  local ft = vim.filetype.match { buf = proxy_bufnr, filename = info.filepath }
  if ft then
    vim.bo[proxy_bufnr].filetype = ft
    log("Filetype=%s set on proxy %d for %s", ft, proxy_bufnr, info.filepath)
  end

  codediff_to_proxy[codediff_bufnr] = {
    proxy_bufnr = proxy_bufnr,
    real_path = real_path,
    reused_existing = false,
  }
  log("Created proxy %d for %s as %s (commit=%s)", proxy_bufnr, info.filepath, proxy_path, info.commit)
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
  local clients = vim.lsp.get_clients { bufnr = proxy }
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

local function with_proxy_window(fn)
  with_current_proxy(function(proxy)
    if not vim.api.nvim_buf_is_valid(proxy) then
      return
    end
    local win = vim.api.nvim_get_current_win()
    local orig_buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_win_set_buf(win, proxy)
    local ok, err = pcall(fn, proxy)
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(orig_buf) then
      vim.api.nvim_win_set_buf(win, orig_buf)
    end
    if not ok then
      error(err)
    end
  end)
end

---@param method string
---@param opts? {always_list?: boolean, extend_params?: fun(params: table)}
local function request_proxy_locations(method, opts)
  opts = opts or {}
  local _, proxy = get_lsp_client()
  if not proxy then
    return
  end
  vim.lsp.buf_request_all(proxy, method, function(client)
    local params = make_position_params(client, proxy)
    if opts.extend_params then
      opts.extend_params(params)
    end
    return params
  end, function(results)
    local matches = {}
    for client_id, res in pairs(results) do
      local client = vim.lsp.get_client_by_id(client_id)
      if client and res and res.result then
        local locations = vim.islist(res.result) and res.result or { res.result }
        for _, location in ipairs(locations) do
          matches[#matches + 1] = {
            location = location,
            offset_encoding = client.offset_encoding or "utf-16",
          }
        end
      end
    end
    handle_location_matches(matches, { always_list = opts.always_list })
  end)
end

function M.hover()
  with_proxy_window(function(proxy)
    vim.api.nvim_buf_call(proxy, vim.lsp.buf.hover)
  end)
end

function M.definition()
  request_proxy_locations "textDocument/definition"
end

function M.references()
  request_proxy_locations("textDocument/references", {
    always_list = true,
    extend_params = function(params)
      params.context = { includeDeclaration = true }
    end,
  })
end

function M.declaration()
  request_proxy_locations "textDocument/declaration"
end

function M.implementation()
  request_proxy_locations("textDocument/implementation", {
    always_list = true,
  })
end

function M.type_definition()
  request_proxy_locations "textDocument/typeDefinition"
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
  with_proxy_window(function(proxy)
    vim.api.nvim_buf_call(proxy, vim.lsp.buf.code_action)
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
    if winid then
      return
    end
    local cr_ok, cr = pcall(require, "pi.cr")
    if cr_ok and cr.show_annotation_under_cursor and cr.show_annotation_under_cursor() then
      return
    end
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
  if
    not entry.reused_existing
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
