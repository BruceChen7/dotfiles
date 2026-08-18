-- Specs for pi.cr.map pure logic.
describe("pi.cr.map.scope_to_session", function()
  local map = require "pi.cr.map"

  it("maps empty args to the status explorer", function()
    local r = map.scope_to_session {}
    assert.is_true(r.ok)
    assert.equal("status", r.scope.kind)
    assert.equal("status", map.scope_to_session(nil).scope.kind)
  end)

  it("maps --cached to the staged explorer", function()
    local r = map.scope_to_session { "--cached" }
    assert.is_true(r.ok)
    assert.equal("staged", r.scope.kind)
  end)

  it("maps <base>...HEAD to a merge-base range", function()
    local r = map.scope_to_session { "main...HEAD" }
    assert.is_true(r.ok)
    assert.equal("range", r.scope.kind)
    assert.equal("main", r.scope.base)
    assert.equal("HEAD", r.scope.target)
  end)

  it("defaults an empty target to HEAD", function()
    local r = map.scope_to_session { "main..." }
    assert.is_true(r.ok)
    assert.equal("main", r.scope.base)
    assert.equal("HEAD", r.scope.target)
  end)

  it("rejects unknown arguments", function()
    local r = map.scope_to_session { "--stat" }
    assert.is_false(r.ok)
    assert.matches("unsupported", r.reason)
    assert.is_false(map.scope_to_session({ "a", "b" }).ok)
  end)
end)

describe("pi.cr.map.keymap_buffers", function()
  local map = require "pi.cr.map"

  it("keeps the modified buffer for an untracked single-pane view", function()
    assert.same({ 9 }, map.keymap_buffers(nil, 9))
  end)

  it("keeps whichever side exists and does not install the same buffer twice", function()
    assert.same({ 3 }, map.keymap_buffers(3, nil))
    assert.same({ 3, 4 }, map.keymap_buffers(3, 4))
    assert.same({ 4 }, map.keymap_buffers(4, 4))
  end)
end)

describe("pi.cr.map.parse_codediff_url", function()
  local map = require "pi.cr.map"

  it("parses a hex-sha virtual buffer and restores the root slash", function()
    local r = map.parse_codediff_url "codediff:///Users/me/work/repo///abc123def456/src/foo.lua"
    assert.truthy(r)
    assert.equal("/Users/me/work/repo", r.git_root)
    assert.equal("abc123def456", r.commit)
    assert.equal("src/foo.lua", r.filepath)
  end)

  it("parses a :0 staged index buffer", function()
    local r = map.parse_codediff_url "codediff:///Users/me/work/repo///:0/src/foo.lua"
    assert.truthy(r)
    assert.equal("/Users/me/work/repo", r.git_root)
    assert.equal(":0", r.commit)
    assert.equal("src/foo.lua", r.filepath)
  end)

  it("parses symbolic refs (HEAD)", function()
    local r = map.parse_codediff_url "codediff:///Users/me/work/repo///HEAD/src/foo.lua"
    assert.truthy(r)
    assert.equal("HEAD", r.commit)
  end)

  it("parses the four-slash form (root already starts with /)", function()
    local r = map.parse_codediff_url "codediff:////private/tmp/repo///:0/a.txt"
    assert.truthy(r)
    assert.equal("/private/tmp/repo", r.git_root)
    assert.equal(":0", r.commit)
    assert.equal("a.txt", r.filepath)
  end)

  it("returns nil for non-codediff names", function()
    assert.is_nil(map.parse_codediff_url "/Users/me/work/repo/src/foo.lua")
    assert.is_nil(map.parse_codediff_url "")
    assert.is_nil(map.parse_codediff_url(nil))
  end)

  it("returns nil for malformed codediff urls", function()
    assert.is_nil(map.parse_codediff_url "codediff:///no-separator")
    assert.is_nil(map.parse_codediff_url "codediff:///root///onlycommit")
  end)
end)

describe("pi.cr.map.hunk_repair_target", function()
  local map = require "pi.cr.map"

  -- codediff hunk shape: { original = {start_line, end_line}, modified = {...} }
  local function hunk(orig_start, orig_end, mod_start, mod_end)
    return {
      original = { start_line = orig_start, end_line = orig_end },
      modified = { start_line = mod_start, end_line = mod_end },
    }
  end

  it("returns nil when no hunk lies past the buffer", function()
    local changes = { hunk(3, 4, 3, 4), hunk(8, 9, 9, 10) }
    assert.is_nil(map.hunk_repair_target(changes, "modified", 10))
    assert.is_nil(map.hunk_repair_target(changes, "original", 10))
  end)

  it("repairs an EOF deletion on the modified side to the last line", function()
    -- 8-line file reduced to 5: the deletion hunk starts one past the buffer
    local changes = { hunk(6, 9, 6, 6) }
    assert.equal(5, map.hunk_repair_target(changes, "modified", 5))
  end)

  it("repairs an EOF addition on the original side to the last line", function()
    -- 5-line HEAD file with appended lines: orig side hunk starts past the end
    local changes = { hunk(3, 4, 3, 4), hunk(6, 6, 6, 7) }
    assert.equal(5, map.hunk_repair_target(changes, "original", 5))
    -- the modified side (6 lines) has no past-end hunk
    assert.is_nil(map.hunk_repair_target(changes, "modified", 6))
  end)

  it("repairs when a later hunk lies past the end and the cursor could not advance", function()
    local changes = { hunk(3, 4, 3, 4), hunk(8, 9, 8, 8) }
    assert.equal(7, map.hunk_repair_target(changes, "modified", 7))
  end)

  it("returns nil for empty buffers", function()
    assert.is_nil(map.hunk_repair_target({ hunk(1, 2, 1, 2) }, "modified", 0))
  end)
end)

describe("pi.cr.map.build_snippet", function()
  local map = require "pi.cr.map"

  local lines = {}
  for i = 1, 20 do
    lines[i] = "line" .. i
  end

  it("returns centered windows up to the cap", function()
    local s = map.build_snippet(lines, 10, 5)
    -- anchor 10 with cap 5: first = 10 - 2 = 8, last = 12
    assert.equal("line8\nline9\nline10\nline11\nline12", s)
  end)

  it("defaults the cap to 10", function()
    local s = map.build_snippet(lines, 10)
    assert.equal(10, select(2, s:gsub("\n", "\n")) + 1)
  end)

  it("clamps near the top of the buffer", function()
    assert.equal("line1\nline2\nline3", map.build_snippet(lines, 1, 3))
  end)

  it("clamps near the bottom of the buffer", function()
    assert.equal("line18\nline19\nline20", map.build_snippet(lines, 20, 3))
  end)

  it("clamps out-of-range anchors", function()
    assert.equal("line1", map.build_snippet(lines, -5, 1))
    assert.equal("line20", map.build_snippet(lines, 999, 1))
  end)

  it("returns empty for empty buffers or non-positive caps", function()
    assert.equal("", map.build_snippet({}, 1, 10))
    assert.equal("", map.build_snippet(lines, 1, 0))
    assert.equal("", map.build_snippet(lines, 1, -1))
  end)
end)

describe("pi.cr.map.build_context", function()
  local map = require "pi.cr.map"

  it("returns line numbers and anchor metadata for the comment popup", function()
    local context = map.build_context({ "one", "two", "three", "four", "five" }, 3, 3)
    assert.same({ "two", "three", "four" }, context.lines)
    assert.equal(2, context.start_line)
    assert.equal(4, context.end_line)
    assert.equal(3, context.anchor_line)
  end)

  it("normalizes a legacy snippet into the context DTO", function()
    assert.same({
      lines = { "a", "b" },
      start_line = 9,
      end_line = 10,
      anchor_line = 10,
    }, map.normalize_context({ snippet = "a\nb", context_start = 9, context_anchor = 10 }, 10))
  end)
end)

describe("pi.cr.map.popup_geometry", function()
  local map = require "pi.cr.map"

  it("places the popup near the source cursor and clamps it to the screen", function()
    assert.same(
      { row = 4, col = 13 },
      map.popup_geometry(
        { row = 2, col = 5, cursor_row = 3, cursor_col = 5 },
        { lines = 30, columns = 100 },
        { width = 40, height = 10 }
      )
    )
    assert.same(
      { row = 17, col = 58 },
      map.popup_geometry(
        { row = 25, col = 90, cursor_row = 10, cursor_col = 20 },
        { lines = 30, columns = 100 },
        { width = 40, height = 10 }
      )
    )
  end)
end)

-- Regression: comment jumps on deleted files. Deleted files render as a
-- single original-side pane (single_side == "original"); the modified side is
-- a scratch buffer that never grows, so the jump must target the original
-- side, and must give up ("hopeless") once that side has settled shorter than
-- the comment line instead of burning the retry budget.
describe("pi.cr.map.jump_landing", function()
  local map = require "pi.cr.map"

  local function view(single_side, modified_lines, original_lines)
    return {
      single_side = single_side,
      modified_lines = modified_lines,
      original_lines = original_lines,
    }
  end

  it("lands on the modified side for normal views", function()
    local r = map.jump_landing(view(nil, 100, 100), 50, 0)
    assert.equal("ready", r.status)
    assert.equal("modified", r.side)
  end)

  it("lands on the original side for deleted-file views", function()
    local r = map.jump_landing(view("original", 1, 100), 50, 0)
    assert.equal("ready", r.status)
    assert.equal("original", r.side)
  end)

  it("accepts a target line equal to the last line", function()
    local r = map.jump_landing(view(nil, 50, 50), 50, 0)
    assert.equal("ready", r.status)
  end)

  it("waits while the side is still loading", function()
    local r = map.jump_landing(view(nil, 1, 100), 50, 3)
    assert.equal("wait", r.status)
    local r2 = map.jump_landing(view("original", 1, 1), 50, 3)
    assert.equal("wait", r2.status)
    assert.equal("original", r2.side)
  end)

  it("gives up once the deleted-file side settled shorter than the line", function()
    local r = map.jump_landing(view("original", 1, 20), 50, 10)
    assert.equal("hopeless", r.status)
    assert.equal("original", r.side)
  end)

  it("gives up once a normal view settled shorter than the line", function()
    local r = map.jump_landing(view(nil, 20, 20), 50, 10)
    assert.equal("hopeless", r.status)
    assert.equal("modified", r.side)
  end)

  it("keeps waiting below the hopeless stability threshold", function()
    local r = map.jump_landing(view("original", 1, 20), 50, 9)
    assert.equal("wait", r.status)
  end)
end)
