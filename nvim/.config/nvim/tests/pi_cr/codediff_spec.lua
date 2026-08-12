-- Regression spec: reinstall-chain completion logic for deleted-file views.
--
-- Bug: with a deleted file selected, the reinstall chain waited for
-- session.modified.relative == target, but deleted files render as a single
-- original-side pane whose modified ref is empty — the condition never became
-- true, so every selection of a deleted file burned the chain's full retry
-- budget (60 x 50ms of vim.wait), and rapid Tab navigation piled up
-- concurrent chains, saturating the main loop.
--
-- These are pure value-in/value-out helpers from pi.cr.codediff (exposed via
-- the _shown_file / _view_matches smoke hooks); the async chain behavior
-- itself is exercised by the headless repro (tests outside this suite).
describe("pi.cr.codediff reinstall completion", function()
  local codediff = require "pi.cr.codediff"

  local function session(original, modified, single_side)
    return {
      original = original and { relative = original } or nil,
      modified = modified and { relative = modified } or nil,
      single_side = single_side,
    }
  end

  describe("shown_file", function()
    it("returns the modified side for normal views", function()
      local s = session("a.txt", "a.txt")
      assert.are.equal("a.txt", codediff._shown_file(s))
    end)

    it("falls back to the original side for deleted files (empty modified ref)", function()
      local s = session("gone.txt", "")
      assert.are.equal("gone.txt", codediff._shown_file(s))
    end)

    it("returns the modified side for added/untracked files (empty original ref)", function()
      local s = session("", "new.txt")
      assert.are.equal("new.txt", codediff._shown_file(s))
    end)

    it("returns empty when nothing is shown yet", function()
      assert.are.equal("", codediff._shown_file(session("", "")))
      assert.are.equal("", codediff._shown_file(nil))
    end)
  end)

  describe("view_matches", function()
    it("matches a normal file via the modified side", function()
      local s = session("a.txt", "a.txt")
      assert.is_true(codediff._view_matches(s, "a.txt"))
      assert.is_false(codediff._view_matches(s, "b.txt"))
    end)

    it("matches a deleted file via the original side", function()
      local s = session("gone.txt", "")
      assert.is_true(codediff._view_matches(s, "gone.txt"))
    end)

    it("matches the VirtualFileLoaded target (empty modified ref) for deleted files", function()
      local s = session("gone.txt", "")
      assert.is_true(codediff._view_matches(s, ""))
    end)

    it("does not match a different file", function()
      local s = session("gone.txt", "")
      assert.is_false(codediff._view_matches(s, "other.txt"))
      assert.is_false(codediff._view_matches(nil, "other.txt"))
    end)
  end)
end)
