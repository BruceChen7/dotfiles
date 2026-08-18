-- Specs for pi.cr.panel pure tree building.
describe("pi.cr.panel.build_tree_rows", function()
  local panel = require "pi.cr.panel"

  local function comment(id, file, line, type, text)
    return { id = id, file = file, line = line, type = type or "note", comment = text or "" }
  end

  it("returns empty rows for no comments", function()
    assert.same({}, panel.build_tree_rows({}, {}))
  end)

  it("groups by dir and file, sorted by line then type (root files first)", function()
    local comments = {
      comment(1, "src/cr/a.ts", 10, "fix", "one"),
      comment(2, "src/cr/a.ts", 5, "note", "two"),
      comment(3, "src/cr/b.ts", 1, "question", "three"),
      comment(4, "README.md", 2, "note", "four"),
    }
    local rows = panel.build_tree_rows(comments, {})
    assert.same({
      { depth = 0, kind = "file", key = "f:README.md", label = "README.md", count = 1, hidden = false },
      { depth = 1, kind = "comment", id = 4, type = "note", line = 2, text = "four", hidden = false },
      { depth = 0, kind = "dir", key = "d:src/cr", label = "src/cr/", count = 3, hidden = false },
      { depth = 1, kind = "file", key = "f:src/cr/a.ts", label = "a.ts", count = 2, hidden = false },
      { depth = 2, kind = "comment", id = 2, type = "note", line = 5, text = "two", hidden = false },
      { depth = 2, kind = "comment", id = 1, type = "fix", line = 10, text = "one", hidden = false },
      { depth = 1, kind = "file", key = "f:src/cr/b.ts", label = "b.ts", count = 1, hidden = false },
      { depth = 2, kind = "comment", id = 3, type = "question", line = 1, text = "three", hidden = false },
    }, rows)
  end)

  it("hides comments under a folded file but keeps the file row", function()
    local comments = { comment(1, "src/a.ts", 1, "note", "x") }
    local rows = panel.build_tree_rows(comments, { ["f:src/a.ts"] = true })
    local comments_rows = 0
    for _, row in ipairs(rows) do
      if row.kind == "comment" then
        comments_rows = comments_rows + 1
      end
    end
    assert.equal(0, comments_rows)
    assert.equal(2, #panel.visible_rows(rows))
  end)

  it("hides everything under a folded dir", function()
    local comments = { comment(1, "src/a.ts", 1, "note", "x"), comment(2, "src/b.ts", 1, "note", "y") }
    local rows = panel.build_tree_rows(comments, { ["d:src"] = true })
    assert.equal(1, #panel.visible_rows(rows))
    assert.equal("dir", rows[1].kind)
  end)

  it("preserves newlines in comment text for multiline rendering", function()
    local rows = panel.build_tree_rows({ comment(1, "a.ts", 1, "note", "line1\nline2") }, {})
    assert.equal("line1\nline2", rows[#rows].text)
  end)

  it("sorts files alphabetically within a dir", function()
    local comments = { comment(1, "src/z.ts", 1, "note", "z"), comment(2, "src/a.ts", 1, "note", "a") }
    local rows = panel.build_tree_rows(comments, {})
    assert.equal("a.ts", rows[2].label)
    assert.equal("z.ts", rows[4].label)
  end)

  it("builds multiline display rows and maps continuation lines to the comment", function()
    local rows = panel.build_tree_rows({ comment(1, "a.ts", 3, "note", "line1\nline2") }, {})
    local model = panel.build_render_model(rows, {}, 1, 60, function(text)
      return text
    end)
    assert.same({ "Comments (1)", "▾ a.ts (1)", "  [NOTE] :3  line1", "             line2" }, model.lines)
    assert.equal(rows[2], model.display_rows[3])
    assert.equal(rows[2], model.display_rows[4])
    assert.equal(3, model.selected_line)
  end)
end)
