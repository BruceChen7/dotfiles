-- pi.cr.diff: unified diff parsing + git diff wrapper.
-- Pure logic module: no windows, no keymaps. Input: git diff text. Output: structured file diffs.

local M = {}

local DEFAULT_CONTEXT_LINES = 3

---@class CrHunkLine
---@field kind "context"|"add"|"del"
---@field text string
---@field old_line number|nil
---@field new_line number|nil
---@field no_newline boolean|nil

---@class CrHunk
---@field old_start number
---@field old_count number
---@field new_start number
---@field new_count number
---@field lines CrHunkLine[]

---@class CrFileDiff
---@field path string
---@field old_path string|nil
---@field binary boolean
---@field additions number
---@field deletions number
---@field hunks CrHunk[]

--- Parse a single `a,b` or `a` range from a hunk header.
---@param range string
---@return number, number
local function parse_range(range)
  local start, count = range:match "^(%d+),(%d+)$"
  if start then
    return tonumber(start), tonumber(count)
  end
  return tonumber(range) or 1, 1
end

--- Parse unified diff output into per-file structures.
---@param output string raw `git diff` output (no color)
---@return CrFileDiff[]
function M.parse(output)
  local files = {} ---@type CrFileDiff[]
  local current ---@type CrFileDiff|nil
  local hunk ---@type CrHunk|nil
  local old_line, new_line

  local function start_file()
    current = { path = nil, old_path = nil, binary = false, additions = 0, deletions = 0, hunks = {} }
    table.insert(files, current)
    hunk = nil
  end

  for line in (output .. "\n"):gmatch "(.-)\n" do
    if line:sub(1, 11) == "diff --git " then
      start_file()
    elseif current then
      if line:sub(1, 6) == "--- a/" then
        current.old_path = line:sub(7)
      elseif line:sub(1, 6) == "+++ b/" then
        current.path = line:sub(7)
      elseif line:sub(1, 4) == "+++ " then
        local path = line:sub(5)
        if path ~= "/dev/null" then
          current.path = path:gsub("^b/", "")
        end
      elseif line:sub(1, 6) == "Binary" then
        current.binary = true
      elseif line:sub(1, 2) == "@@" then
        local old_range, new_range = line:match "^@@ %-([%d,]+) %+([%d,]+) @@"
        if old_range and new_range then
          local old_start, old_count = parse_range(old_range)
          local new_start, new_count = parse_range(new_range)
          hunk = {
            old_start = old_start,
            old_count = old_count,
            new_start = new_start,
            new_count = new_count,
            lines = {},
          }
          table.insert(current.hunks, hunk)
          old_line = old_start
          new_line = new_start
        end
      elseif hunk then
        local kind = line:sub(1, 1)
        local text = line:sub(2)
        if kind == " " then
          table.insert(hunk.lines, {
            kind = "context",
            text = text,
            old_line = old_line,
            new_line = new_line,
          })
          old_line = old_line + 1
          new_line = new_line + 1
        elseif kind == "+" then
          table.insert(hunk.lines, { kind = "add", text = text, new_line = new_line })
          current.additions = current.additions + 1
          new_line = new_line + 1
        elseif kind == "-" then
          table.insert(hunk.lines, { kind = "del", text = text, old_line = old_line })
          current.deletions = current.deletions + 1
          old_line = old_line + 1
        elseif kind == "\\" then
          local previous = hunk.lines[#hunk.lines]
          if previous then
            previous.no_newline = true
          end
        end
      end
    end
  end

  for _, file in ipairs(files) do
    if file.path == nil then
      file.path = file.old_path or ""
    end
  end

  return files
end

--- Run `git diff --no-color --no-ext-diff -U<context> <diffArgs>` and return raw output.
--- --no-ext-diff defends against user-level `diff.external` / GIT_EXTERNAL_DIFF / attributes
--- drivers (e.g. a side-by-side difft tool): the review UI always needs plain unified text.
---@param diff_args string[] scope args from the CR session (e.g. {"--cached"}, {"main...HEAD"})
---@param context_lines number|nil hunk context lines (default 3)
---@return string
function M.run(diff_args, context_lines)
  local args = {
    "git",
    "diff",
    "--no-color",
    "--no-ext-diff",
    "-U" .. tostring(context_lines or DEFAULT_CONTEXT_LINES),
  }
  vim.list_extend(args, diff_args or {})
  return vim.fn.system(args)
end

--- Collect the hunk containing a new-side line (or the hunk whose new range starts at it).
---@param file CrFileDiff
---@param new_line number
---@return CrHunk|nil
function M.hunk_for_new_line(file, new_line)
  for _, hunk in ipairs(file.hunks) do
    if new_line >= hunk.new_start and new_line < hunk.new_start + math.max(hunk.new_count, 1) then
      return hunk
    end
  end
  return nil
end

--- Build a snippet of diff lines (with +/-/space prefixes) around a new-side line.
---@param file CrFileDiff
---@param new_line number
---@param context number|nil lines of context before/after (default 3)
---@return string
function M.snippet_for_new_line(file, new_line, context)
  local hunk = M.hunk_for_new_line(file, new_line)
  if not hunk then
    return ""
  end
  local context_n = context or DEFAULT_CONTEXT_LINES

  -- Anchor: index of the first line whose new_line >= target (adds/context only).
  local anchor = nil
  for index, entry in ipairs(hunk.lines) do
    if entry.kind ~= "del" and entry.new_line and entry.new_line >= new_line then
      anchor = index
      break
    end
  end
  -- Deleted-only hunks (or target before any add/context): anchor at hunk start.
  anchor = anchor or 1

  local first = math.max(1, anchor - context_n)
  local last = math.min(#hunk.lines, anchor + context_n)
  local out = {}
  for index = first, last do
    local entry = hunk.lines[index]
    local prefix = entry.kind == "add" and "+" or (entry.kind == "del" and "-" or " ")
    table.insert(out, prefix .. entry.text)
  end
  return table.concat(out, "\n")
end

return M
