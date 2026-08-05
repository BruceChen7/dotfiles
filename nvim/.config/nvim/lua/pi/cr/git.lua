-- pi.cr.git: staging / unstaging and diff refresh for the review UI.

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

--- Toggle stage/unstage for one path (or all paths when path is nil).
---@param app table shared review state ({config, files, selected})
---@param path string|nil file path, or nil for the root "stage all" row
function M.toggle(app, path)
  if not is_worktree_scope(app.config and app.config.diffArgs) then
    notify "Space 仅适用于工作区变更（unstaged / staged）"
    return
  end

  local staged = is_staged_scope(app.config and app.config.diffArgs)
  local args
  if path == nil then
    args = staged and { "git", "restore", "--staged", "--", "." } or { "git", "add", "-A" }
  elseif staged then
    args = { "git", "restore", "--staged", "--", path }
  else
    args = { "git", "add", "--", path }
  end

  if run(args) then
    M.refresh(app)
  end
end

--- Re-run the diff and re-render the whole review UI.
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

  local ui = require "pi.cr.ui"
  ui.render_all()
end

return M
