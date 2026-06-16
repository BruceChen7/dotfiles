--- LSP Proxy for Pi CR codediff virtual buffers
---
--- codediff deliberately prevents LSP on its virtual buffers (codediff:// URIs)
--- because LSP servers can't handle custom URI schemes and crash or misbehave.
---
--- This module creates hidden "proxy" buffers with real file paths, attaches LSP
--- to them, and redirects LSP operations from the codediff view buffers through
--- the proxy buffers using direct LSP client requests (avoids nvim_buf_call to
--- prevent BufEnter re-entrancy / E1312 errors).
---
--- Architecture:
---
---   codediff buffer (codediff://.../src/foo.go)
---     │  no LSP (codediff disables it)
---     │  Keymaps: gd/grr/gD/K overridden → direct LSP requests
---     │
---     └──► proxy buffer (/path/to/project/src/foo.go)
---           LSP attached: ✓  (buftype="" during setup → "nofile" after LspAttach)
---           Content synced from codediff buffer before each request
---           Request params: proxy URI + codediff window cursor position
---
--- Only the MODIFIED (right) side gets a proxy.  The ORIGINAL (left) side
--- is reference-only and doesn't need LSP.

local M = {}

--- @type table<codediff_bufnr, {proxy_bufnr: number, real_path: string}>
local codediff_to_proxy = {}

--------------------------------------------------------------------------------
--- Logging
--------------------------------------------------------------------------------

local function log(fmt, ...)
  vim.notify(string.format(fmt, ...), vim.log.levels.DEBUG, { title = "Pi CR LSP" })
end

--------------------------------------------------------------------------------
--- URL parsing
--------------------------------------------------------------------------------

--- Parse a codediff:// URL.
--- @param url string
--- @return {git_root: string, commit: string, filepath: string}|nil
local function parse_url(url)
  -- Order matters: SHA hex branch first (tightest matcher), then symbolic, then :N
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

--------------------------------------------------------------------------------
--- Proxy buffer lifecycle
--------------------------------------------------------------------------------

--- Determine if a codediff buffer is the MODIFIED (right) side.
--- @param codediff_bufnr number
--- @return boolean|nil  nil = undetermined (proxy anyway)
local function is_modified_side(codediff_bufnr)
  local ok, session = pcall(require, "codediff.ui.lifecycle.session")
  if not ok then
    return nil
  end
  local diffs = session.get_active_diffs()
  if not diffs then
    return nil
  end

  local tabpage = vim.api.nvim_get_current_tabpage()
  local diff = diffs[tabpage]
  if diff then
    if diff.modified_bufnr == codediff_bufnr then
      return true
    end
    if diff.original_bufnr == codediff_bufnr then
      return false
    end
  end
  -- Slow path: scan all tracked tabs
  for _, d in pairs(diffs) do
    if d.modified_bufnr == codediff_bufnr then
      return true
    end
    if d.original_bufnr == codediff_bufnr then
      return false
    end
  end
  return nil
end

--- @param codediff_bufnr number
--- @return number|nil
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

--- Sync content from codediff buffer to its proxy buffer.
--- @param codediff_bufnr number
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
--- Two codediff panels (original + modified) for the same real_path share
--- a SINGLE proxy buffer — Neovim doesn't allow two buffers with the same
--- name, and gopls refuses paths outside the module root.
---
--- Content is synced on-demand in `sync_content` just before each LSP
--- request, overwriting the previous revision's content.  This keeps
--- gopls's workspace view consistent while matching the cursor position
--- to the correct revision.
---
--- @param codediff_bufnr number
--- @return number|nil proxy bufnr
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

  -- First codediff buffer for this real_path: create a new proxy.
  local proxy_bufnr = vim.api.nvim_create_buf(false, false)
  pcall(vim.api.nvim_buf_set_name, proxy_bufnr, real_path)

  -- Copy content.
  local lines = vim.api.nvim_buf_get_lines(codediff_bufnr, 0, -1, false)
  pcall(vim.api.nvim_buf_set_lines, proxy_bufnr, 0, -1, false, lines)

  vim.bo[proxy_bufnr].bufhidden = "hide"
  vim.bo[proxy_bufnr].modified = false

  -- Switch buftype to "nofile" AFTER LSP attaches.
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

  -- Set filetype → LSP attaches.
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
  log("Created proxy %d for %s (commit=%s)", proxy_bufnr, info.filepath, info.commit)
  return proxy_bufnr
end

--------------------------------------------------------------------------------
--- Direct LSP request helpers  (NO nvim_buf_call)
--------------------------------------------------------------------------------

--- Get the first LSP client attached to the proxy of the current codediff buffer.
--- Also syncs content before returning.
--- @return table|nil, number|nil  (client, proxy_bufnr)
local function get_lsp_client()
  local bufnr = vim.api.nvim_get_current_buf()
  local proxy = M.get_proxy(bufnr)
  if not proxy then
    return nil, nil
  end

  -- Ensure the codediff content is present in the proxy buffer so that
  -- byte-offset calculations (cursor → line:character) are correct.
  sync_content(bufnr)

  local clients = vim.lsp.get_clients { bufnr = proxy }
  if #clients == 0 then
    log("No LSP client for proxy %d (not yet attached or filetype not matched)", proxy)
    return nil, proxy -- proxy exists but LSP not ready
  end
  return clients[1], proxy
end

--- Build LSP position params using the proxy URI + current window cursor.
--- Unlike `vim.lsp.util.make_position_params(0, ...)` which reads the line
--- from the CODEDIFF buffer (whose content may be from a different git
--- revision), this reads the line from the PROXY buffer so the character
--- offset matches what gopls received via textDocument/didOpen.
--- @param client table
--- @param proxy_bufnr number
--- @return table
local function make_position_params(client, proxy_bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0) -- { 1-indexed line, 0-indexed byte col }
  local offenc = client.offset_encoding or "utf-16"
  local row = cursor[1] - 1
  local col = cursor[2]
  -- Read the line from the PROXY buffer so the offset calculation matches the
  -- content that gopls received.
  local line = vim.api.nvim_buf_get_lines(proxy_bufnr, row, row + 1, false)[1] or ""
  -- Convert byte column to the LSP position encoding (utf-16 by default).
  if col > 0 then
    col = vim.str_utfindex(line, offenc, col, false)
  end
  return {
    textDocument = { uri = vim.uri_from_bufnr(proxy_bufnr) },
    position = { line = row, character = col },
  }
end

--- Attempt to open a single location (jump) or multiple (quickfix).
local function handle_locations(locations, offset_encoding)
  if not locations or #locations == 0 then
    return
  end
  locations = vim.islist(locations) and locations or { locations }
  if #locations == 1 then
    local loc = locations[1]
    local uri = loc.uri or loc.targetUri
    if uri then
      local bufnr = vim.uri_to_bufnr(uri)
      if bufnr ~= 0 then
        -- `vim.lsp.util.show_document` uses `nvim_win_set_buf` internally,
        -- which does NOT add a jumplist entry — breaking Ctrl-O after gd.
        -- Use `:edit` instead (adds proper jumplist entry), but only when
        -- the target file differs from the current buffer to avoid a
        -- pointless reload.
        local cur_buf = vim.api.nvim_get_current_buf()
        if bufnr ~= cur_buf then
          local fname = vim.api.nvim_buf_get_name(bufnr)
          vim.cmd("edit " .. vim.fn.fnameescape(fname))
        end
        -- Position cursor at the definition
        local range = loc.range or loc.targetSelectionRange
        if range then
          local pos = vim.pos.lsp(bufnr, range.start, offset_encoding)
          vim.api.nvim_win_set_cursor(0, { pos.row + 1, pos.col })
          vim.cmd "normal! zz"
        end
      end
    end
  else
    vim.fn.setqflist(vim.lsp.util.locations_to_items(locations, offset_encoding))
    vim.cmd "copen"
  end
end

--------------------------------------------------------------------------------
--- LSP operation wrappers (direct client.request, no nvim_buf_call)
--------------------------------------------------------------------------------

function M.hover()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(proxy, cursor[1] - 1, cursor[1], false)[1] or ""
  vim.notify(
    string.format(
      "[Pi CR] hover row=%d col=%d char=%d line_len=%d uri=%s",
      params.position.line,
      params.position.character,
      cursor[2],
      #line,
      params.textDocument.uri
    ),
    vim.log.levels.INFO
  )
  local handler = vim.lsp.handlers["textDocument/hover"]
  if handler then
    client:request("textDocument/hover", params, function(err, result, ctx)
      if err then
        vim.notify("[Pi CR] hover error: " .. tostring(err), vim.log.levels.WARN)
      end
      pcall(handler, err, result, ctx)
    end, proxy)
  end
end

function M.definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local client, proxy = get_lsp_client()
  vim.notify(string.format(
    "[Pi CR gd] bufnr=%d proxy=%s client=%s",
    bufnr, tostring(proxy), client and client.name or "nil"
  ), vim.log.levels.INFO)
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  client:request("textDocument/definition", params, function(err, result)
    if err then
      local err_msg = type(err) == "table" and vim.inspect(err) or tostring(err)
      vim.notify("[Pi CR gd] error: " .. err_msg, vim.log.levels.WARN)
      return
    end
    if not result or (vim.islist(result) and #result == 0) then
      vim.notify("[Pi CR gd] no results", vim.log.levels.INFO)
      return
    end
    handle_locations(result, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.references()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  params.context = { includeDeclaration = true }
  client:request("textDocument/references", params, function(err, result)
    if err or not result then
      return
    end
    handle_locations(result, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.declaration()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  client:request("textDocument/declaration", params, function(err, result)
    if err or not result then
      return
    end
    handle_locations(result, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.implementation()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  client:request("textDocument/implementation", params, function(err, result)
    if err or not result then
      return
    end
    handle_locations(result, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.type_definition()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  client:request("textDocument/typeDefinition", params, function(err, result)
    if err or not result then
      return
    end
    handle_locations(result, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.incoming_calls()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  client:request("textDocument/incomingCalls", params, function(err, result)
    if err or not result then
      return
    end
    -- Flatten incomingCalls result which is { from: Location, fromRanges: Range[] }[]
    local locations = vim.tbl_map(function(ic)
      return ic.from
    end, result)
    handle_locations(locations, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.outgoing_calls()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local params = make_position_params(client, proxy)
  client:request("textDocument/outgoingCalls", params, function(err, result)
    if err or not result then
      return
    end
    local locations = vim.tbl_map(function(oc)
      return oc.to
    end, result)
    handle_locations(locations, client.offset_encoding or "utf-16")
  end, proxy)
end

function M.rename()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  vim.ui.input({ prompt = "New name: " }, function(new_name)
    if not new_name or new_name == "" then
      return
    end
    local params = make_position_params(client, proxy)
    params.newName = new_name
    client:request("textDocument/rename", params, function(err, result)
      if err or not result then
        return
      end
      if result.documentChanges then
        -- Apply workspace edit manually
        pcall(vim.lsp.util.apply_workspace_edit, result, client.offset_encoding or "utf-16")
      elseif result.changes then
        pcall(vim.lsp.util.apply_workspace_edit, result, client.offset_encoding or "utf-16")
      end
    end, proxy)
  end)
end

function M.code_action()
  local client, proxy = get_lsp_client()
  if not client then
    return
  end
  local offenc = client.offset_encoding or "utf-16"
  -- Use make_range_params for the cursor-range, then overlay proxy URI
  local params = vim.lsp.util.make_range_params(0, offenc)
  params.textDocument.uri = vim.uri_from_bufnr(proxy)
  params.context = {
    diagnostics = vim.diagnostic.get(proxy, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 }),
  }
  client:request("textDocument/codeAction", params, function(err, result)
    if err or not result then
      return
    end
    local actions = vim.tbl_filter(function(a)
      return a.title and not a.disabled
    end, result)
    if #actions == 0 then
      return
    end
    vim.ui.select(actions, {
      prompt = "Code actions",
      format_item = function(a)
        return a.title
      end,
    }, function(choice)
      if not choice then
        return
      end
      if choice.edit then
        pcall(vim.lsp.util.apply_workspace_edit, choice.edit, offenc)
      end
      if choice.command then
        client:request("workspace/executeCommand", {
          command = choice.command.command,
          arguments = choice.command.arguments,
        }, function() end, proxy)
      end
    end)
  end, proxy)
end

--------------------------------------------------------------------------------
--- Keymap setup
--------------------------------------------------------------------------------

--- Install buffer-local keymaps that redirect LSP operations through direct
--- requests to the proxy's LSP client (no nvim_buf_call).
--- @param bufnr number  codediff buffer to install keymaps on
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

  -- K: ufo fold peek → CR annotation → LSP hover (via direct request)
  map("n", "K", function()
    -- 1) ufo
    local winid = require("ufo").peekFoldedLinesUnderCursor()
    if winid then
      return
    end
    -- 2) CR annotation
    local cr_ok, cr = pcall(require, "pi.cr")
    if cr_ok and cr.show_annotation_under_cursor and cr.show_annotation_under_cursor() then
      return
    end
    -- 3) LSP hover
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
  if vim.api.nvim_buf_is_valid(entry.proxy_bufnr) then
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

  -- Only proxy the modified (right) side.
  local is_mod = is_modified_side(bufnr)
  if is_mod == false then
    log("Skipping proxy for original (left) side, bufnr=%d", bufnr)
    return
  end

  vim.schedule(function()
    local proxy = create_proxy(bufnr)
    if proxy then
      M.setup_keymaps(bufnr)
      -- Verify LSP attachment after a short delay (deferred so the FileType
      -- autocmd / lsp-start cycle has time to complete).
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(proxy) then
          return
        end
        local clients = vim.lsp.get_clients { bufnr = proxy }
        if #clients == 0 then
          log(
            "WARNING: No LSP client attached to proxy %d after 500ms. "
              .. "Check that lsp-setup/nvim-lspconfig handles filetype=%s "
              .. "on buffers that are not displayed in a window.",
            proxy,
            vim.bo[proxy].filetype or "?"
          )
        else
          log(
            "LSP client(s) attached to proxy %d: %s",
            proxy,
            table.concat(
              vim.tbl_map(function(c)
                return c.name
              end, clients),
              ", "
            )
          )
        end
      end, 500)
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
