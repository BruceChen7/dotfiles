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

--- Build a snippet window from buffer lines around an anchor line (1-based).
--- Cap is a maximum, not a target: near the buffer edges the window simply
--- shrinks. Used for comment payload snippets (replaces the old diff-prefixed
--- lines; output is plain file lines, no +/+/space prefixes).
---@param lines string[] full buffer lines
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
  cap = cap or 10
  if cap <= 0 or #lines == 0 then
    return ""
  end
  anchor = math.max(1, math.min(anchor, #lines))
  local first = math.max(1, math.min(anchor - math.floor(cap / 2), #lines - cap + 1))
  local last = math.min(#lines, first + cap - 1)
  return table.concat(lines, "\n", first, last)
end

return M
