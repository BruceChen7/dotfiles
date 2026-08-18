-- pi.cr.map: pure decision logic for the codediff adapter.
-- Value in / value out: no windows, no keymaps, no side effects.
-- Test surface: tests/pi_cr/map_spec.lua

local M = {}

---@class CrScope
---@field kind "status"|"staged"|"range"
---@field base string|nil merge-base range base (range scope)
---@field target string|nil range target, defaults to "HEAD" (range scope)

---@class CrScopeResult
---@field ok boolean
---@field scope CrScope|nil
---@field reason string|nil

--- Map the CR session's diffArgs (from the cr-diffview extension) to a
--- codediff explorer scope.
---   []               -> status explorer (unstaged + staged + untracked)
---   ["--cached"]     -> staged-only explorer (HEAD vs :0)
---   ["<base>...HEAD"]-> merge-base explorer (base vs target)
--- Anything else is unsupported (the extension only produces these three).
---@param diff_args string[]|nil
---@return CrScopeResult
function M.scope_to_session(diff_args)
  diff_args = diff_args or {}
  if #diff_args == 0 then
    return { ok = true, scope = { kind = "status" } }
  end
  if #diff_args == 1 then
    local arg = diff_args[1]
    if arg == "--cached" then
      return { ok = true, scope = { kind = "staged" } }
    end
    local base, target = arg:match "^(.+)%.%.%.(.+)$"
    if base then
      return {
        ok = true,
        scope = { kind = "range", base = base, target = target ~= "" and target or "HEAD" },
      }
    end
    local trailing = arg:match "^(.+)%.%.%.$"
    if trailing then
      return { ok = true, scope = { kind = "range", base = trailing, target = "HEAD" } }
    end
  end
  return { ok = false, reason = "unsupported diffArgs: [" .. table.concat(diff_args, ", ") .. "]" }
end

--- Return the concrete view buffers that need Pi CR mappings. A single-pane
--- view leaves the absent side nil (untracked: original; deleted: modified),
--- so this must not use ipairs on { original, modified }: ipairs stops at the
--- first nil and would silently omit the remaining, visible pane.
---@param original_buf number|nil
---@param modified_buf number|nil
---@return number[]
function M.keymap_buffers(original_buf, modified_buf)
  local buffers, seen = {}, {}
  local candidates = { original_buf, modified_buf }
  for index = 1, 2 do
    local buf = candidates[index]
    if buf ~= nil and not seen[buf] then
      seen[buf] = true
      buffers[#buffers + 1] = buf
    end
  end
  return buffers
end

--- Parse a codediff:// virtual buffer name into repo identity.
--- Format (mirrors codediff.core.virtual_file.create_url):
---   codediff:///<git-root>///<commit>/<filepath>
--- The scheme's trailing slashes eat the root's leading "/" (same quirk
--- cr-tags.lua documents), so the returned git_root always starts with "/".
--- Commit segment covers every form the plugin emits: hex SHA, SHA^,
--- symbolic refs (HEAD/branches) and :N staged refs — none contain "/".
---@param bufname string|nil
---@return {git_root: string, commit: string, filepath: string}|nil
function M.parse_codediff_url(bufname)
  if not bufname or bufname:sub(1, 12) ~= "codediff:///" then
    return nil
  end
  local root, commit, filepath = bufname:match "^codediff:///(.-)///([^/]+)/(.+)$"
  if not root or not commit or not filepath then
    return nil
  end
  if root:sub(1, 1) ~= "/" then
    root = "/" .. root
  end
  return { git_root = root, commit = commit, filepath = filepath }
end

--- Repair target for codediff's silent hunk-navigation failure.
---
--- codediff's next_hunk/prev_hunk jump to a hunk's start_line and swallow the
--- set_cursor error, so when the start line lies one past the buffer's end
--- (an end-of-file deletion on the modified side, an end-of-file addition on
--- the original side) the keys appear dead: the nav reports success, the
--- cursor never moves. The caller detects the no-move condition in the same
--- window; given that, a past-end hunk on the shown side is exactly the
--- failure signature, and the repair lands on the buffer's last line — where
--- the deleted/added tail sits.
---
--- Pure decision: return the line to land on, or nil when no hunk lies past
--- the buffer (the nav genuinely had nowhere to go).
---@param changes table[] codediff hunk mappings ({original, modified} ranges)
---@param side "original"|"modified" which side of the diff this pane shows
---@param line_count number lines in the pane's buffer
---@return number|nil
function M.hunk_repair_target(changes, side, line_count)
  if line_count < 1 then
    return nil
  end
  for _, mapping in ipairs(changes) do
    local range = side == "original" and mapping.original or mapping.modified
    if range and range.start_line > line_count then
      return line_count -- EOF hunk beyond the buffer: land on the tail
    end
  end
  return nil
end

--- Build a snippet window from buffer lines around an anchor line (1-based).
--- The window always fills the cap when the buffer is large enough, shifting
--- toward the edges as the anchor approaches them. Used for comment payload
--- snippets (replaces the old diff-prefixed lines; output is plain file
--- lines, no +/+/space prefixes).
---@param lines string[] full buffer lines
---@param anchor number 1-based new-side line
---@param cap number|nil max snippet lines (default 10)
---@return string
function M.build_snippet(lines, anchor, cap)
  local context = M.build_context(lines, anchor, cap)
  return table.concat(context.lines, "\n")
end

--- Build structured context for a comment editor.
---@param lines string[] full buffer lines
---@param anchor number 1-based new-side line
---@param cap number|nil max context lines (default 10)
---@return {start_line: number, end_line: number, anchor_line: number, lines: string[]}
function M.build_context(lines, anchor, cap)
  cap = cap or 10
  if cap <= 0 or #lines == 0 then
    return { start_line = 1, end_line = 0, anchor_line = 1, lines = {} }
  end
  anchor = math.max(1, math.min(anchor, #lines))
  local first = math.max(1, math.min(anchor - math.floor(cap / 2), #lines - cap + 1))
  local last = math.min(#lines, first + cap - 1)
  local context_lines = {}
  for index = first, last do
    context_lines[#context_lines + 1] = lines[index]
  end
  return {
    start_line = first,
    end_line = last,
    anchor_line = anchor,
    lines = context_lines,
  }
end

---@class CrCommentContext
---@field lines string[]
---@field start_line number
---@field end_line number
---@field anchor_line number

--- Normalize the context DTO at the comment seam. The legacy flat fields are
--- accepted so artifact/session callers can migrate without changing payloads.
---@param input table|nil
---@param fallback_line number
---@return CrCommentContext
function M.normalize_context(input, fallback_line)
  input = input or {}
  local lines = input.lines or input.context_lines or {}
  if #lines == 0 and input.snippet then
    lines = {}
    for line in (input.snippet .. "\n"):gmatch "(.-)\n" do
      lines[#lines + 1] = line
    end
  end
  if #lines == 0 then
    return { lines = {}, start_line = fallback_line, end_line = fallback_line - 1, anchor_line = fallback_line }
  end
  local start_line = input.start_line or input.context_start or math.max(1, fallback_line - math.floor(#lines / 2))
  local anchor_line = input.anchor_line or input.context_anchor or fallback_line
  return {
    lines = lines,
    start_line = start_line,
    end_line = start_line + #lines - 1,
    anchor_line = anchor_line,
  }
end

--- Compute a floating comment window position from plain screen snapshots.
---@param source {row: number, col: number, cursor_row: number, cursor_col: number}
---@param screen {lines: number, columns: number}
---@param size {width: number, height: number}
---@return {row: number, col: number}
function M.popup_geometry(source, screen, size)
  local row = source.row + source.cursor_row - 1
  local col = source.col + source.cursor_col + 3
  return {
    row = math.max(1, math.min(row, math.max(1, screen.lines - size.height - 3))),
    col = math.max(1, math.min(col, math.max(1, screen.columns - size.width - 2))),
  }
end

--- before a too-short side is treated as settled. Virtual buffers start empty
--- and fill asynchronously, so a short count alone is not final; 10 ticks (~500ms)
--- is well past the async load, so a count still below the target then is
--- permanent for that view.
local HOPELESS_STABLE_TICKS = 10

--- Decide where a comment jump can land, from a view snapshot.
---
--- The modified side normally carries the target file; deleted files render
--- as a single original-side pane (single_side == "original") whose modified
--- side is a scratch buffer that never grows, so the original side is the
--- only meaningful landing target. Without this the caller waits for the
--- target line on the empty modified side and burns its full retry budget.
---
--- Returns:
---   {status="ready", side}     -> land the cursor on that side now
---   {status="wait", side}      -> the side is still loading; keep waiting
---   {status="hopeless", side}  -> the side has settled with fewer lines than
---                                 the target; the jump can never land
---
---@param view {single_side: string|nil, modified_lines: number, original_lines: number}
---@param target_line number
---@param stable_ticks number consecutive ticks the checked side's line count
---                        has been unchanged (0 = first observation)
---@return {status: "ready"|"wait"|"hopeless", side: "modified"|"original"}
function M.jump_landing(view, target_line, stable_ticks)
  local side = view.single_side == "original" and "original" or "modified"
  local lines = side == "original" and view.original_lines or view.modified_lines
  if lines >= target_line then
    return { status = "ready", side = side }
  end
  if stable_ticks >= HOPELESS_STABLE_TICKS then
    return { status = "hopeless", side = side }
  end
  return { status = "wait", side = side }
end

return M
