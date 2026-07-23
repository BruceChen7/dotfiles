--- LSP Proxy for Pi CR codediff virtual buffers
---
--- codediff deliberately prevents LSP on its virtual buffers (codediff:// URIs)
--- because LSP servers can't handle custom URI schemes and crash or misbehave.
---
--- This module creates REAL temp files via `git show <commit>:<path>` and loads
--- them into hidden buffers. LSP attaches natively (file:// URI) so ALL LSP
--- features work without per-feature proxy code.
---
--- Architecture:
---
---   codediff buffer (codediff://.../src/foo.go)    temp buffer (/repo/.git/cr-lsp-temp/<commit>/src/foo.go)
---     │  LSP: ✗                                        LSP: ✓ (real file URI, auto-attached)
---     │                                                 │
---     └── nvim_buf_call(temp, vim.lsp.buf.definition) ──┘
---                                                       All features work natively:
---                                                       hover, definition, references,
---                                                       rename, code_action, completion,
---                                                       diagnostics, inlay hints,
---                                                       signature help, code lenses

local M = {}

--- @type table<codediff_bufnr, {temp_bufnr: number, temp_path: string, real_path: string, commit: string}>
local codediff_to_temp = {}

local function log(fmt, ...)
  if vim.env.PI_CR_LSP_DEBUG then
    vim.notify(string.format(fmt, ...), vim.log.levels.DEBUG, { title = "Pi CR LSP" })
  end
end

--------------------------------------------------------------------------------
--- URL parsing
--------------------------------------------------------------------------------

--- Parse a codediff:// URL into its components.
--- @param url string
--- @return {git_root: string, commit: string, filepath: string}|nil
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

--------------------------------------------------------------------------------
--- Temp file management
--------------------------------------------------------------------------------

--- Ensure a temp file exists on disk for the given git revision.
---
--- Creates `<git_root>/.git/cr-lsp-temp/<safe_commit>/<filepath>` via
--- `git show <commit>:<filepath>`.  The file is reused if it already exists
--- (immutable revisions are effectively cached on disk; for mutable revisions
--- like `:0` the caller may request a refresh).
---
--- @param git_root string  absolute path to git repository root
--- @param commit  string  commit hash, ref, or `:0`
--- @param filepath string  repo-relative file path
--- @param opts? {force?: boolean}  if true, re-checkout even if file exists
--- @return string full_path
local function ensure_temp_file(git_root, commit, filepath, opts)
  opts = opts or {}
  local safe_commit = commit:gsub("[^a-zA-Z0-9_:]", "_")
  local dir = git_root .. "/.git/cr-lsp-temp/" .. safe_commit
  local full_path = dir .. "/" .. filepath

  if opts.force or vim.fn.filereadable(full_path) == 0 then
    vim.fn.mkdir(vim.fn.fnamemodify(full_path, ":h"), "p")
    local result = vim.fn.system {
      "git",
      "-C",
      git_root,
      "show",
      commit .. ":" .. filepath,
    }
    if vim.v.shell_error == 0 then
      local lines = vim.split(result, "\n", { plain = true })
      -- git show appends a trailing newline; strip the empty last line
      if #lines > 0 and lines[#lines] == "" then
        lines[#lines] = nil
      end
      vim.fn.writefile(lines, full_path)
    else
      -- File doesn't exist in this revision (added or deleted in this commit)
      vim.fn.writefile({ "" }, full_path)
    end
  end

  return full_path
end

--- Get or create a temp buffer for a codediff buffer.
---
--- Each codediff buffer gets its own temp buffer (independent mapping).
--- Two panels for the same file at different commits get two independent
--- temp files.
---
--- @param codediff_bufnr number
--- @return number|nil temp_bufnr
local function get_or_create_temp_buf(codediff_bufnr)
  -- Reuse existing mapping if still valid
  local entry = codediff_to_temp[codediff_bufnr]
  if entry and vim.api.nvim_buf_is_valid(entry.temp_bufnr) then
    return entry.temp_bufnr
  end

  local name = vim.api.nvim_buf_get_name(codediff_bufnr)
  local info = parse_url(name)
  if not info then
    return nil
  end

  local real_path = info.git_root .. "/" .. info.filepath
  local temp_path = ensure_temp_file(info.git_root, info.commit, info.filepath)

  -- Create a hidden buffer for the temp file
  local temp_bufnr = vim.api.nvim_create_buf(false, false)

  -- Load the temp file content into the buffer
  local lines = vim.fn.readfile(temp_path)
  vim.api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, lines)

  -- Name the buffer as the temp file path so LSP sees a real file:// URI.
  -- This allows the LSP server to resolve the file relative to the workspace
  -- root and apply the correct language server.
  pcall(vim.api.nvim_buf_set_name, temp_bufnr, temp_path)

  vim.bo[temp_bufnr].bufhidden = "hide"
  vim.bo[temp_bufnr].modified = false

  -- Set filetype via filename match so LSP can auto-attach.
  -- LspAttach fires automatically for the real file:// URI.
  local ft = vim.filetype.match { filename = info.filepath }
  if ft then
    vim.bo[temp_bufnr].filetype = ft
    log("Filetype=%s set on temp buffer %d for %s", ft, temp_bufnr, info.filepath)
  end

  codediff_to_temp[codediff_bufnr] = {
    temp_bufnr = temp_bufnr,
    temp_path = temp_path,
    real_path = real_path,
    commit = info.commit,
  }

  log("Created temp buffer %d for %s (commit=%s)", temp_bufnr, info.filepath, info.commit)
  return temp_bufnr
end

--- Refresh the temp buffer content for a mutable revision (e.g., `:0`).
--- Called when the staged index may have changed.
--- @param codediff_bufnr number
local function refresh_temp_buf(codediff_bufnr)
  local entry = codediff_to_temp[codediff_bufnr]
  if not entry then
    return
  end

  local info = parse_url(vim.api.nvim_buf_get_name(codediff_bufnr))
  if not info then
    return
  end

  -- Re-checkout the temp file (force refresh)
  local temp_path = ensure_temp_file(info.git_root, info.commit, info.filepath, { force = true })

  -- Reload the buffer content
  if vim.api.nvim_buf_is_valid(entry.temp_bufnr) then
    local lines = vim.fn.readfile(temp_path)
    vim.api.nvim_buf_set_lines(entry.temp_bufnr, 0, -1, false, lines)
  end
end

--------------------------------------------------------------------------------
--- LSP operation redirection
--------------------------------------------------------------------------------

--- Execute an LSP function in the context of the temp buffer.
---
--- Uses nvim_buf_call so that `vim.lsp.buf_request(0, ...)` targets the temp
--- buffer's LSP clients.  The cursor position in the current window is used
--- directly — content is identical between the codediff virtual buffer and the
--- temp file, so the cursor offset maps correctly.
---
--- @param codediff_bufnr number
--- @param fn fun()
--- @return boolean success
local function with_temp_buf(codediff_bufnr, fn)
  local entry = codediff_to_temp[codediff_bufnr]
  if not entry or not vim.api.nvim_buf_is_valid(entry.temp_bufnr) then
    local temp_bufnr = get_or_create_temp_buf(codediff_bufnr)
    if not temp_bufnr then
      return false
    end
    entry = codediff_to_temp[codediff_bufnr]
  end

  local clients = vim.lsp.get_clients { bufnr = entry.temp_bufnr }
  if #clients == 0 then
    return false
  end

  vim.api.nvim_buf_call(entry.temp_bufnr, fn)
  return true
end

local function with_current_temp_buf(fn)
  return with_temp_buf(vim.api.nvim_get_current_buf(), fn)
end

--- Wrapper that temporarily shows the temp buffer in the current window,
--- runs the function, then restores the original buffer.
---
--- Required for LSP functions that create floating windows or UI elements
--- relative to the on-screen buffer (hover, code_action, signature help).
---
--- @param fn fun()
local function with_temp_buf_window(fn)
  local codediff_bufnr = vim.api.nvim_get_current_buf()
  local entry = codediff_to_temp[codediff_bufnr]
  if not entry or not vim.api.nvim_buf_is_valid(entry.temp_bufnr) then
    local temp_bufnr = get_or_create_temp_buf(codediff_bufnr)
    if not temp_bufnr then
      return
    end
    entry = codediff_to_temp[codediff_bufnr]
  end

  local win = vim.api.nvim_get_current_win()
  local orig_buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_win_set_buf(win, entry.temp_bufnr)
  local ok, err = pcall(fn)
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(orig_buf) then
    vim.api.nvim_win_set_buf(win, orig_buf)
  end
  if not ok then
    log("with_temp_buf_window error: %s", tostring(err))
  end
end

--------------------------------------------------------------------------------
--- LSP public API (called from keymaps)
--------------------------------------------------------------------------------

function M.hover()
  with_temp_buf_window(function()
    vim.lsp.buf.hover()
  end)
end

function M.definition()
  with_current_temp_buf(vim.lsp.buf.definition)
end

function M.references()
  with_current_temp_buf(function()
    vim.lsp.buf.references()
  end)
end

function M.declaration()
  with_current_temp_buf(vim.lsp.buf.declaration)
end

function M.implementation()
  with_current_temp_buf(vim.lsp.buf.implementation)
end

function M.type_definition()
  with_current_temp_buf(vim.lsp.buf.type_definition)
end

function M.incoming_calls()
  with_current_temp_buf(vim.lsp.buf.incoming_calls)
end

function M.outgoing_calls()
  with_current_temp_buf(vim.lsp.buf.outgoing_calls)
end

function M.rename()
  with_current_temp_buf(vim.lsp.buf.rename)
end

function M.code_action()
  with_temp_buf_window(function()
    vim.lsp.buf.code_action()
  end)
end

--- Trigger completion via the temp buffer's LSP.
--- Typically bound to <C-Space> or <C-x><C-o> in insert mode.
function M.completion()
  with_current_temp_buf(function()
    vim.lsp.buf.completion()
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
  end, "Peek Fold / CR Annotation / LSP Hover (via temp proxy)")

  map("n", "gd", M.definition, "LSP Definition (via temp proxy)")
  map("n", "grr", M.references, "LSP References (via temp proxy)")
  map("n", "gD", M.declaration, "LSP Declaration (via temp proxy)")
  map("n", "\\gi", M.implementation, "LSP Implementation (via temp proxy)")
  map("n", "\\gy", M.type_definition, "LSP Type Definition (via temp proxy)")
  map("n", "<leader>li", M.incoming_calls, "LSP Incoming Calls (via temp proxy)")
  map("n", "<leader>lo", M.outgoing_calls, "LSP Outgoing Calls (via temp proxy)")
  map("n", "<leader>lr", M.rename, "LSP Rename (via temp proxy)")
  map({ "n", "x" }, "<leader>ca", M.code_action, "LSP Code Action (via temp proxy)")

  log("Keymaps installed on bufnr=%d", bufnr)
end

--------------------------------------------------------------------------------
--- Cleanup
--------------------------------------------------------------------------------

--- Clean up the temp buffer for a single codediff buffer.
--- Called on BufDelete codediff://*.
function M.cleanup(codediff_bufnr)
  local entry = codediff_to_temp[codediff_bufnr]
  if not entry then
    return
  end

  -- Only delete the temp buffer if no window is showing it.
  if vim.api.nvim_buf_is_valid(entry.temp_bufnr) and #vim.fn.win_findbuf(entry.temp_bufnr) == 0 then
    pcall(vim.api.nvim_buf_delete, entry.temp_bufnr, { force = true })
  end
  codediff_to_temp[codediff_bufnr] = nil
end

local function cleanup_all()
  for bufnr, _ in pairs(codediff_to_temp) do
    M.cleanup(bufnr)
  end
end

--- Remove the entire cr-lsp-temp directory tree on VimLeavePre.
--- This is a best-effort cleanup; leftover files are harmless and will be
--- overwritten on the next session.
local function cleanup_temp_dirs()
  local seen = {}
  for _, entry in pairs(codediff_to_temp) do
    if not seen[entry.temp_path] then
      -- Extract the .git/cr-lsp-temp directory from the temp path
      local git_temp_dir = entry.temp_path:match "^(.+/.git/cr%-lsp%-temp)/"
      if git_temp_dir and not seen[git_temp_dir] then
        seen[git_temp_dir] = true
        pcall(vim.fn.delete, git_temp_dir, "rf")
      end
    end
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
    local temp_bufnr = get_or_create_temp_buf(bufnr)
    if temp_bufnr then
      M.setup_keymaps(bufnr)
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("PiCRLspTempProxy", { clear = true })

  -- When codediff finishes loading a virtual file, create a temp buffer and
  -- attach LSP keymaps to the codediff buffer.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeDiffVirtualFileLoaded",
    callback = function(args)
      on_virtual_file_loaded(args.data)
    end,
  })

  -- When codediff closes, clean up all temp buffers.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeDiffClose",
    callback = function()
      vim.schedule(cleanup_all)
    end,
  })

  -- When a codediff buffer is deleted (bufhidden=wipe), clean up its mapping.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    pattern = "codediff://*",
    callback = function(args)
      M.cleanup(args.buf)
    end,
  })

  -- Clean up temp directories on exit.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = cleanup_temp_dirs,
  })
end

return M
