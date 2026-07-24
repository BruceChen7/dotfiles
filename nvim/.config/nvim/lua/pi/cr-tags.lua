--- Ctags Definition Peek (replaces cr-lsp.lua)
---
--- Instead of materialising git snapshots and proxying LSP operations,
--- this module queries ctags (via `vim.fn.taglist()`) for the symbol
--- under the cursor and shows its definition in a floating window.
---
--- Behaves like skywind3000/vim-preview's PreviewTag but uses a floating
--- window instead of a split previewwindow:
---
---   <M-;> / K
---     ├─ first press  → open float with first definition
---     ├─ same symbol  → cycle to next (wraps around)
---     └─ new symbol   → fresh lookup, index = 0
---
---   Inside float (focusable):
---     j/k     → scroll    C-d/C-u → half page
---     q/Esc   → close     n/p     → next/prev definition
---
--- The tag index is maintained by gutentags (already configured), so no
--- additional indexing setup is needed.

local M = {}

--- @class TagCache
--- @field word string symbol name
--- @field tags table[] filtered tag list
--- @field index number current position in list (0-based)

local state = {
  floating_buf = nil,
  floating_win = nil,
  source_bufnr = nil,
  --- @type TagCache?
  cache = nil,
}

--------------------------------------------------------------------------------
--- Floating window management
--------------------------------------------------------------------------------

local function close_floating()
  if state.source_bufnr then
    pcall(vim.keymap.del, "n", "<C-l>", { buffer = state.source_bufnr })
  end

  if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
    vim.api.nvim_win_close(state.floating_win, false)
  end
  state.floating_win = nil
  state.floating_buf = nil
  state.source_bufnr = nil
end

--- Update float content (without closing/reopening).
--- @param lines string[]
--- @param def_idx number|nil
local function update_float_content(lines, def_idx)
  local buf = state.floating_buf
  local win = state.floating_win
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  -- Replace all content
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "readonly", true)

  -- Clear old highlights and re-highlight definition line
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  if def_idx and def_idx >= 0 and def_idx < #lines then
    vim.api.nvim_buf_add_highlight(buf, -1, "IncSearch", def_idx, 0, -1)
  end

  -- Reset cursor to top of float
  pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
end

--- Show definition content in a floating window.
--- @param lines string[] display lines
--- @param def_idx number|nil 0-based index of definition line
--- @param source_bufnr number
--- @param tag_filename string|nil  original tag filename for filetype detection
local function show_floating(lines, def_idx, source_bufnr, tag_filename)
  -- If float already exists for this source, just update content
  if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win)
      and state.source_bufnr == source_bufnr then
    update_float_content(lines, def_idx)
    return
  end

  -- Close any existing float from other buffer
  close_floating()

  if not lines or #lines == 0 then
    return
  end

  -- Calculate dimensions (generous)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(math.max(width, 60), math.floor(vim.o.columns * 0.92))
  -- Height: cap at 65% screen, but at least 6 lines
  local height = math.min(#lines, math.max(6, math.floor(vim.o.lines * 0.65)))

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Filetype from the definition filename (not source buffer)
  local ft = tag_filename and vim.filetype.match { filename = tag_filename } or ""
  if ft ~= "" then
    vim.bo[buf].filetype = ft
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  -- Open float relative to the current window (not cursor), so no
  -- source window scrolling is needed for positioning.
  local source_winid = vim.api.nvim_get_current_win()
  local win_width = vim.api.nvim_win_get_width(source_winid)
  local float_width = math.min(width, math.floor(win_width * 0.95))

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "win",
    width = float_width,
    height = height,
    row = 1,
    col = math.floor((win_width - float_width) / 2),
    style = "minimal",
    border = "single",
    focusable = true,
    zindex = 100,
    noautocmd = true,
  })

  -- Floating windows inherit window-local options from the source window.
  -- codediff uses scrollbind for side-by-side panes; if the float inherits it,
  -- scrolling the float scrolls the source pane too.
  vim.api.nvim_win_set_option(win, "scrollbind", false)
  vim.api.nvim_win_set_option(win, "cursorbind", false)
  vim.api.nvim_win_set_option(win, "diff", false)
  vim.api.nvim_win_set_option(win, "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder")

  -- Highlight definition line
  if def_idx and def_idx >= 0 and def_idx < #lines then
    vim.api.nvim_buf_add_highlight(buf, -1, "IncSearch", def_idx, 0, -1)
  end

  -- Set float cursor after disabling scrollbind, then enter the float.
  if def_idx and def_idx >= 0 and def_idx < #lines then
    pcall(vim.api.nvim_win_set_cursor, win, { def_idx + 1, 0 })
  end
  vim.api.nvim_set_current_win(win)

  state.floating_buf = buf
  state.floating_win = win
  state.source_bufnr = source_bufnr

  -- ── Keymaps inside the float ──────────────────────────────────
  local close_fn = function()
    close_floating()
  end

  -- Close keys
  vim.keymap.set("n", "q", close_fn, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_fn, { buffer = buf, nowait = true, silent = true })


  -- Cycle next/prev inside float
  vim.keymap.set("n", "n", function()
    M.definition_peek { advance = true }
  end, { buffer = buf, nowait = true, silent = true, desc = "Next definition" })

  vim.keymap.set("n", "p", function()
    M.definition_peek { advance = -1 }
  end, { buffer = buf, nowait = true, silent = true, desc = "Previous definition" })

  -- Focus float from source window.
  vim.keymap.set("n", "<C-l>", function()
    if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
      vim.api.nvim_set_current_win(state.floating_win)
    end
  end, { buffer = source_bufnr, nowait = true, silent = true, desc = "Focus float window" })
end

--------------------------------------------------------------------------------
--- Ctags resolution
--------------------------------------------------------------------------------

--- Resolve the line number from a ctags tag entry.
--- @param tag table
--- @return number|nil
local function resolve_tag_lnum(tag)
  if not tag or not tag.cmd then
    return nil
  end

  -- Case 1: cmd is a line number string
  local num = tonumber(tag.cmd)
  if num then
    return num
  end

  -- Case 2: extract search pattern from /.../
  local pattern = tag.cmd:match("^/(.+)/")
  if not pattern then
    return nil
  end

  -- Extract line number from Vim \%l atom if present (e.g. \%263l from /\%263l\%6c/)
  local line_via_atom = pattern:match("\\%%(%d+)l")
  if line_via_atom then
    return tonumber(line_via_atom)
  end

  local ok, re = pcall(vim.regex, pattern)
  if not ok or not re then
    return nil
  end

  local lines = vim.fn.readfile(tag.filename)
  if not lines then
    return nil
  end

  for i, line in ipairs(lines) do
    if re:match_str(line) then
      return i
    end
  end

  return nil
end

--- Get git repo root.
--- @return string|nil
local function get_git_root()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)

  if name:find("^codediff://") == 1 then
    local git_root = name:match("^codediff:///(.-)///")
    if git_root and git_root ~= "" then
      -- git_root from codediff URL is missing leading / because the
      -- URI scheme's trailing slash consumes it (see create_url in
      -- codediff/core/virtual_file.lua). Prepend / to make it absolute.
      return vim.fn.resolve("/" .. git_root)
    end
  end

  local root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if root and root ~= "" then
    return root
  end

  return nil
end

--- Resolve tag filename to absolute path.
---
--- Tries in order:
---   1. tag.filename itself (if absolute or readable)
---   2. git_root / tag.filename
---   3. cwd / tag.filename
---   4. findfile() with basename
---
--- @param tag table
--- @param git_root string|nil
--- @return string|nil
local function resolve_filename(tag, git_root)
  if not tag.filename then
    return nil
  end

  -- Already absolute and readable
  if tag.filename:sub(1, 1) == "/" then
    if vim.fn.filereadable(tag.filename) == 1 then
      return tag.filename
    end
    -- Absolute but not readable → try below
  end

  -- Relative: try git_root first
  if git_root and git_root ~= "" then
    local candidate = git_root .. "/" .. tag.filename
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  -- Try current working directory
  local cwd = vim.fn.getcwd()
  if cwd and cwd ~= "" then
    local candidate = cwd .. "/" .. tag.filename
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  -- Fallback: findfile() searches 'path'
  local found = vim.fn.findfile(tag.filename)
  if found and found ~= "" then
    return vim.fn.fnamemodify(found, ":p")
  end

  -- Last resort: try just the basename
  local basename = vim.fn.fnamemodify(tag.filename, ":t")
  if basename and basename ~= tag.filename then
    local found2 = vim.fn.findfile(basename)
    if found2 and found2 ~= "" then
      return vim.fn.fnamemodify(found2, ":p")
    end
  end

  return nil
end

--- Format a single-line description for a tag (used in header).
--- @param tag table
--- @param lnum number|nil
--- @param index number|nil 1-based position
--- @param total number|nil
local function format_tag_line(tag, lnum, index, total)
  local shortname = vim.fn.fnamemodify(tag.filename, ":~:.")
  local line_info = lnum and (":" .. lnum) or ""
  local pos = ""
  if index and total and total > 1 then
    pos = string.format(" (%d/%d)", index, total)
  end
  local kind = tag.kind or ""
  return string.format("≡ %s%s [%s]%s", shortname, line_info, kind, pos)
end

--- Build display lines for a tag match — reads the entire file.
--- @param tag table
--- @param index number|nil 1-based position in list
--- @param total number|nil
--- @return string[]|nil lines
--- @return number|nil    def_idx (0-based in display array)
local function build_display_lines(tag, index, total)
  local git_root = get_git_root()
  local filename = resolve_filename(tag, git_root)
  if not filename or vim.fn.filereadable(filename) ~= 1 then
    return nil, nil
  end

  local lnum = resolve_tag_lnum(tag)
  if not lnum then
    return nil, nil
  end

  -- Read entire file
  local all_lines = vim.fn.readfile(filename)
  if not all_lines or #all_lines == 0 then
    return nil, nil
  end

  -- Build display: header + all lines with line numbers
  local header = format_tag_line(tag, lnum, index, total)
  local display = { header, "" }
  local def_idx_in_context = nil

  for i, line in ipairs(all_lines) do
    local marker = (i == lnum) and "→" or " "
    table.insert(display, string.format("%s %5d  %s", marker, i, line))
    if i == lnum then
      def_idx_in_context = #display - 1  -- 0-based
    end
  end

  return display, def_idx_in_context
end

--------------------------------------------------------------------------------
--- Query & filter tags
--------------------------------------------------------------------------------

--- Find the gutentags cache file for a git root.
--- gutentags stores tags in ~/.cache/tags/<cache-key>-.tags
--- where cache-key is the absolute path with / replaced by -.
--- @param git_root string
--- @return string|nil
local function find_gutentags_cache(git_root)
  local cache_dir = vim.g.gutentags_cache_dir
      or vim.fn.expand("~/.cache/tags")
  local cache_key = git_root:gsub("^/", ""):gsub("/", "-")
  local candidate = cache_dir .. "/" .. cache_key .. "-.tags"
  if vim.fn.filereadable(candidate) == 1 then
    return candidate
  end
  return nil
end

--- Query ctags for a word.
---
--- Neovim's default 'tags' option (./.tags;,.tags) searches the directory
--- tree for .tags files, but gutentags stores them in ~/.cache/tags/.
--- If tagfiles() returns empty, we locate the cache file by deriving the
--- cache key from the git root and temporarily prepend it to 'tags'.
---
--- @param word string
--- @return table[]
local function query_tags(word)
  local saved_tags = vim.o.tags
  local tagfiles = vim.fn.tagfiles()

  if #tagfiles == 0 then
    local git_root = get_git_root()
    if git_root then
      local cache_file = find_gutentags_cache(git_root)
      if cache_file then
        vim.o.tags = cache_file .. "," .. saved_tags
      end
    end
  end

  local tags = vim.fn.taglist(word)
  vim.o.tags = saved_tags

  if not tags or #tags == 0 then
    return {}
  end

  local git_root = get_git_root()
  if not git_root then
    return tags
  end

  local repo_tags = {}
  for _, tag in ipairs(tags) do
    local filename = resolve_filename(tag, git_root)
    if filename and filename:sub(1, #git_root) == git_root then
      table.insert(repo_tags, tag)
    end
  end

  return (#repo_tags > 0) and repo_tags or tags
end

--------------------------------------------------------------------------------
--- Public API
--------------------------------------------------------------------------------

--- Peek definition for the symbol under the cursor.
---
--- @param opts? {advance?: boolean|number}
---   advance = true  → cycle forward in cached list
---   advance = -1    → cycle backward
---   advance = false or nil → normal lookup
function M.definition_peek(opts)
  opts = opts or {}
  local current_bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand("<cword>")

  -- ── Cycle mode: float already open for same word ──────────────
  if state.cache
      and state.cache.word == word
      and state.floating_win and vim.api.nvim_win_is_valid(state.floating_win)
      and state.source_bufnr == current_bufnr then
    local total = #state.cache.tags
    if total <= 1 then
      -- Only one definition, float stays but cannot cycle
      return
    end
    if opts.advance == nil or opts.advance == true then
      opts.advance = 1
    end
    state.cache.index = (state.cache.index + opts.advance) % total
    if state.cache.index < 0 then
      state.cache.index = total - 1
    end

    local tag = state.cache.tags[state.cache.index + 1]
    local lines, def_idx = build_display_lines(tag,
      state.cache.index + 1, total)
    if lines then
      show_floating(lines, def_idx, current_bufnr, tag.filename)
    end
    return
  end

  -- ── Float open for different word → close ─────────────────────
  if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
    close_floating()
  end

  -- ── Fresh lookup ─────────────────────────────────────────────
  if not word or word == "" then
    vim.notify("No symbol under cursor", vim.log.levels.INFO, { title = "Pi CR Tags" })
    return
  end

  local tags = query_tags(word)
  if #tags == 0 then
    vim.notify("No definition found for: " .. word, vim.log.levels.INFO, { title = "Pi CR Tags" })
    return
  end

  state.cache = {
    word = word,
    tags = tags,
    index = 0,
  }

  local tag = tags[1]
  local total = #tags
  local lines, def_idx = build_display_lines(tag, 1, total)
  if lines then
    show_floating(lines, def_idx, current_bufnr, tag.filename)
  else
    local git_root = get_git_root()
    local abs_path = resolve_filename(tag, git_root)
    local reason
    if not abs_path then
      reason = "file not found (tag filename: " .. tag.filename .. ")"
    else
      local lnum = resolve_tag_lnum(tag)
      if not lnum then
        reason = "could not resolve line number (cmd: " .. (tag.cmd or "?") .. ")"
      else
        reason = "unknown error"
      end
    end
    vim.notify("Cannot resolve definition: " .. reason,
      vim.log.levels.WARN, { title = "Pi CR Tags" })
  end
end

--- Jump to definition for the symbol under the cursor.
---
--- Unlike definition_peek() which shows a float, this JUMPs to the
--- definition file and positions the cursor at the definition line.
---
--- If the float is already open for the current word, uses the cached tag.
--- Otherwise, does a fresh lookup and jumps to the first match.
function M.jump_to_definition()
  local current_bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand("<cword>")

  -- Use cached tag if float is open for this word
  local tag
  if state.cache and state.cache.word == word
      and state.source_bufnr == current_bufnr then
    tag = state.cache.tags[state.cache.index + 1]
  end

  -- No cache → fresh lookup, take first match
  if not tag then
    if not word or word == "" then
      vim.notify("No symbol under cursor", vim.log.levels.INFO, { title = "Pi CR Tags" })
      return
    end
    local tags = query_tags(word)
    if #tags == 0 then
      vim.notify("No definition found for: " .. word, vim.log.levels.INFO, { title = "Pi CR Tags" })
      return
    end
    tag = tags[1]
  end

  -- Close any open float
  close_floating()

  -- Resolve and jump
  local git_root = get_git_root()
  local filename = resolve_filename(tag, git_root)
  local lnum = resolve_tag_lnum(tag)
  if filename and lnum then
    -- If the view is codediff, use the real file on disk
    vim.cmd(string.format("edit +%d %s", lnum, vim.fn.fnameescape(filename)))
    vim.cmd "normal! zz"
  elseif filename then
    vim.cmd("edit " .. vim.fn.fnameescape(filename))
  else
    vim.notify("Cannot resolve definition location: " .. (tag.filename or "?"),
      vim.log.levels.WARN, { title = "Pi CR Tags" })
  end
end

return M
