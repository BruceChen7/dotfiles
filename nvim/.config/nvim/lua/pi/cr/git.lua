-- pi.cr.git: staging / unstaging, git status, and diff refresh for the review UI.

local M = {}

local function notify(message, level)
  local resolved_level = level or vim.log.levels.INFO
  local function do_notify()
    vim.notify(message, resolved_level, { title = "Pi CR" })
  end
  if vim.in_fast_event() then
    vim.schedule(do_notify)
  else
    do_notify()
  end
end

local function run(args)
  local result = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    notify("git failed: " .. vim.trim(result), vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Whether the current review scope is worktree-based (unstaged or staged).
---@param diff_args string[]|nil
---@return boolean
local function is_worktree_scope(diff_args)
  diff_args = diff_args or {}
  if #diff_args == 0 then
    return true
  end
  return diff_args[1] == "--cached"
end

---@param diff_args string[]|nil
---@return boolean true when the review shows the index (staged) diff
local function is_staged_scope(diff_args)
  return (diff_args or {})[1] == "--cached"
end

--- Parse `git status --porcelain` (XY PATH, ?? for untracked).
--- Quoted/escaped paths are not decoded in v1 (known limitation).
--- Renames ("R  old -> new") keep the target path.
---@param output string
---@return {staged: {path: string, code: string}[], unstaged: {path: string, code: string}[]}
local function parse_status(output)
  local staged, unstaged = {}, {}
  for line in output:gmatch "[^\n]+" do
    local index_col = line:sub(1, 1)
    local worktree_col = line:sub(2, 2)
    local path = line:sub(4)
    if index_col == "?" and worktree_col == "?" then
      unstaged[#unstaged + 1] = { path = path, code = "??" }
    else
      local target = path:match "^.-%s+->%s+(.+)$"
      if target then
        path = target
      end
      if index_col ~= " " then
        staged[#staged + 1] = { path = path, code = index_col }
      end
      if worktree_col ~= " " then
        unstaged[#unstaged + 1] = { path = path, code = worktree_col }
      end
    end
  end
  return { staged = staged, unstaged = unstaged }
end

--- Current index/worktree state for the sidebar sections.
---@return {staged: {path: string, code: string}[], unstaged: {path: string, code: string}[]}
function M.status()
  local output = vim.fn.system { "git", "status", "--porcelain" }
  if vim.v.shell_error ~= 0 then
    return { staged = {}, unstaged = {} }
  end
  return parse_status(output)
end

--- Toggle stage state for one path based on the sidebar section it sits in:
--- Unstaged rows stage the file, Staged rows unstage it.
---@param app table shared review state ({config, files, selected})
---@param section "unstaged"|"staged"
---@param path string
function M.toggle(app, section, path)
  if not is_worktree_scope(app.config and app.config.diffArgs) then
    notify "Space 仅适用于工作区变更（unstaged / staged）"
    return
  end

  local args
  if section == "staged" then
    args = { "git", "restore", "--staged", "--", path }
  else
    args = { "git", "add", "--", path }
  end

  if run(args) then
    M.refresh(app)
  end
end

--- Re-run the diff + git status and re-render the whole review UI.
---@param app table
function M.refresh(app)
  local diff = require "pi.cr.diff"
  local output = diff.run(app.config and app.config.diffArgs, app.context_lines)
  local files = diff.parse(output)

  -- Preserve the selected file by path when it still exists in the diff.
  local selected_path = app.files[app.selected] and app.files[app.selected].path
  local next_selected = 1
  if selected_path then
    for index, file in ipairs(files) do
      if file.path == selected_path then
        next_selected = index
        break
      end
    end
  end

  app.files = files
  app.selected = next_selected
  app.git_status = M.status()

  local ui = require "pi.cr.ui"
  ui.render_all()
end

M.is_worktree_scope = is_worktree_scope
M.is_staged_scope = is_staged_scope

return M
