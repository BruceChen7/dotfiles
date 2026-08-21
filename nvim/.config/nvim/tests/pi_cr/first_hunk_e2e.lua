-- Red-capable E2E loop for: first ]c in Pi CR does nothing, after <Tab>/<S-Tab> away/back works.
-- Run with:
--   scripts/test-pi-cr-first-hunk-e2e.sh

local src = debug.getinfo(1, "S").source:gsub("^@", "")
if not src:match "^/" then
  src = vim.fn.getcwd() .. "/" .. src
end
local config_root = src:match "^(.*)/tests/pi_cr/"
local lazy_root = vim.fn.stdpath "data" .. "/lazy"
local plugin_dirs = {
  config_root,
  lazy_root .. "/plenary.nvim",
  lazy_root .. "/codediff.nvim",
  lazy_root .. "/gitsigns.nvim",
}
for _, dir in ipairs(plugin_dirs) do
  vim.opt.rtp:prepend(dir)
  package.path = dir .. "/lua/?.lua;" .. dir .. "/lua/?/init.lua;" .. package.path
end
package.path = config_root .. "/lua/?.lua;" .. config_root .. "/lua/?/init.lua;" .. package.path

local reports = {}
local cleanup_paths = {}
local done = false
local function log(msg)
  table.insert(reports, msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end
local function finish(code)
  if done then
    return
  end
  done = true
  for _, path in ipairs(cleanup_paths) do
    pcall(vim.fn.delete, path, "rf")
  end
  vim.defer_fn(function()
    if code == 0 then
      vim.cmd "qa!"
    else
      vim.cmd "cq"
    end
  end, 20)
end
local function fail(msg)
  log("[FAIL] " .. msg)
  finish(1)
end
local function pass(msg)
  log("[PASS] " .. msg)
end

vim.notify = function(msg, level, opts)
  log("[notify] " .. tostring(msg))
end

local function system(cmd)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    fail("shell failed: " .. cmd .. "\n" .. out)
    return nil
  end
  return out
end

-- Use the real repo config that maps next_file to <Tab> and enables gitsigns mappings.
-- Minimal init does not source plugin/*.lua; source codediff's plugin entry so codediff://
-- BufReadCmd exists, matching a real lazy.nvim session.
vim.cmd "runtime plugin/codediff.lua"
local ok_cfg, cfg_err = pcall(require, "config.codediff")
if not ok_cfg then
  fail("require config.codediff failed: " .. tostring(cfg_err))
  return
end
if vim.env.PI_CR_E2E_NO_GITSIGNS ~= "1" then
  pcall(require, "config.gitsigns")
else
  log "[SETUP] gitsigns disabled by PI_CR_E2E_NO_GITSIGNS=1"
end

-- Temp repo with two changed files. First hunk in first file is at line 216.
local repo = "/tmp/pi-cr-first-hunk-e2e-" .. tostring(vim.fn.getpid())
table.insert(cleanup_paths, repo)
vim.fn.mkdir(repo, "p")
system("git -C " .. vim.fn.shellescape(repo) .. " init -q")
system(
  "git -C "
    .. vim.fn.shellescape(repo)
    .. " config user.name a && git -C "
    .. vim.fn.shellescape(repo)
    .. " config user.email a@a"
)
local function write_lines(path, count, changed_line)
  local lines = {}
  for i = 1, count do
    lines[i] = (i == changed_line) and ("changed-" .. tostring(i)) or ("line-" .. tostring(i))
  end
  vim.fn.writefile(lines, path)
end
local f1 = repo .. "/a-first.txt"
local f2 = repo .. "/b-second.txt"
write_lines(f1, 260, nil)
write_lines(f2, 120, nil)
system("git -C " .. vim.fn.shellescape(repo) .. " add . && git -C " .. vim.fn.shellescape(repo) .. " commit -qm init")
write_lines(f1, 260, 216)
write_lines(f2, 120, 50)
vim.cmd("cd " .. vim.fn.fnameescape(repo))

local pi = require "pi.cr.codediff"
local lifecycle = require "codediff.ui.lifecycle"
local navigation = require "codediff.ui.view.navigation"
local tabpage
local first_path = "a-first.txt"
local second_path = "b-second.txt"

local function map_owner(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return "<invalid>"
  end
  local entries = {}
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if m.lhs == "]c" or m.lhs == "<Tab>" or m.lhs == "<S-Tab>" then
      table.insert(entries, string.format("%s:%s:%s", m.lhs, tostring(m.desc or ""), tostring(m.expr)))
    end
  end
  return table.concat(entries, ",")
end

local function current_state(label)
  local s = tabpage and lifecycle.get_session(tabpage) or nil
  local ob, mb, ow, mw
  if tabpage then
    ob, mb = lifecycle.get_buffers(tabpage)
    ow, mw = lifecycle.get_windows(tabpage)
  end
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  local mod_line = (mw and vim.api.nvim_win_is_valid(mw)) and vim.api.nvim_win_get_cursor(mw)[1] or -1
  log(
    string.format(
      "[STATE:%s] cur_win=%s cur_buf=%s cur_line=%s tab=%s shown=%s changes=%s ob=%s mb=%s ow=%s mw=%s mod_line=%s cur_gs=%s mb_gs=%s cur_maps={%s} mb_maps={%s} patched=%s",
      label,
      tostring(cur_win),
      tostring(cur_buf),
      tostring(cur_line),
      tostring(tabpage),
      tostring(s and s.modified and s.modified.relative or nil),
      tostring(s and s.stored_diff_result and s.stored_diff_result.changes and #s.stored_diff_result.changes or nil),
      tostring(ob),
      tostring(mb),
      tostring(ow),
      tostring(mw),
      tostring(mod_line),
      tostring(vim.b[cur_buf] and vim.b[cur_buf].gitsigns_enabled),
      tostring(mb and vim.b[mb] and vim.b[mb].gitsigns_enabled),
      map_owner(cur_buf),
      map_owner(mb),
      tostring(navigation._pi_patched)
    )
  )
  return s, ob, mb, ow, mw
end

local function wait_for(predicate, label, timeout_ms, cb)
  local started = vim.loop.hrtime()
  local function tick()
    if done then
      return
    end
    local ok, result = pcall(predicate)
    if ok and result then
      cb(result)
      return
    end
    local elapsed = (vim.loop.hrtime() - started) / 1e6
    if elapsed > timeout_ms then
      current_state("timeout-" .. label)
      fail("timeout waiting for " .. label)
      return
    end
    vim.defer_fn(tick, 20)
  end
  tick()
end

local function feed(lhs, cb)
  local keys = vim.api.nvim_replace_termcodes(lhs, true, false, true)
  vim.api.nvim_feedkeys(keys, "m", false)
  vim.defer_fn(cb, 120)
end

local function focus_modified_and_top()
  local _, _, _, _, mw = current_state "before-focus-mod"
  if not mw or not vim.api.nvim_win_is_valid(mw) then
    fail "modified window invalid"
    return false
  end
  vim.api.nvim_set_current_win(mw)
  pcall(vim.api.nvim_win_set_cursor, mw, { 1, 0 })
  return true
end

local function press_hunk_and_measure(label, expected_line, cb)
  if not focus_modified_and_top() then
    return
  end
  current_state(label .. "-before-]c")
  feed("]c", function()
    local _, _, _, _, mw = current_state(label .. "-after-]c")
    local line = mw and vim.api.nvim_win_is_valid(mw) and vim.api.nvim_win_get_cursor(mw)[1] or -1
    cb(line == expected_line, line)
  end)
end

log "=== Phase 1 E2E loop start ==="
pi.open {
  config = { diffArgs = {}, label = "first-hunk-e2e" },
  finish = function()
    finish(0)
  end,
}

wait_for(
  function()
    -- Find the codediff tab created by pi.open.
    if not tabpage then
      tabpage = pi._state.tabpage
    end
    local s = tabpage and lifecycle.get_session(tabpage) or nil
    return s
      and s.modified
      and s.modified.relative == first_path
      and s.stored_diff_result
      and s.stored_diff_result.changes
      and #s.stored_diff_result.changes > 0
  end,
  "first file ready",
  2500,
  function()
    current_state "first-ready"
    -- 用户不是在 render 完成的同一个 tick 内按键；让 gitsigns/on_attach 等异步
    -- 后写者有机会覆盖 ]c，复现“首按无反应，切 Tab 回来后好”的时序。
    local settle_ms = tonumber(vim.env.PI_CR_E2E_SETTLE_MS or "250") or 250
    log("[SETUP] first settle ms=" .. tostring(settle_ms))
    vim.defer_fn(function()
      current_state "first-settled-before-press"
      press_hunk_and_measure("first", 216, function(first_ok, first_line)
        -- Now emulate user workaround: <Tab> to next file, then <S-Tab> back.
        current_state "before-tab"
        feed("<Tab>", function()
          wait_for(
            function()
              local s = tabpage and lifecycle.get_session(tabpage) or nil
              return s
                and s.modified
                and s.modified.relative == second_path
                and s.stored_diff_result
                and s.stored_diff_result.changes
                and #s.stored_diff_result.changes > 0
            end,
            "second file ready",
            2500,
            function()
              current_state "second-ready"
              feed("<S-Tab>", function()
                wait_for(
                  function()
                    local s = tabpage and lifecycle.get_session(tabpage) or nil
                    return s
                      and s.modified
                      and s.modified.relative == first_path
                      and s.stored_diff_result
                      and s.stored_diff_result.changes
                      and #s.stored_diff_result.changes > 0
                  end,
                  "first file back ready",
                  2500,
                  function()
                    current_state "first-back-ready"
                    press_hunk_and_measure("after-tab-back", 216, function(back_ok, back_line)
                      if (not first_ok) and back_ok then
                        fail(
                          string.format(
                            "REPRODUCED exact symptom: first ]c line=%s, after tab/back line=%s",
                            tostring(first_line),
                            tostring(back_line)
                          )
                        )
                      elseif first_ok and back_ok then
                        pass "No repro: first ]c and after tab/back both work"
                        finish(0)
                      else
                        fail(
                          string.format(
                            "Unexpected verdict: first_ok=%s line=%s back_ok=%s line=%s",
                            tostring(first_ok),
                            tostring(first_line),
                            tostring(back_ok),
                            tostring(back_line)
                          )
                        )
                      end
                    end)
                  end
                )
              end)
            end
          )
        end)
      end)
    end, settle_ms)
  end
)

vim.defer_fn(function()
  if not done then
    current_state "global-timeout"
    fail "global timeout"
  end
end, 8000)
