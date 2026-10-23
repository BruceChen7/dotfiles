describe("pi.cr.comments UI lifecycle", function()
  local comments = require "pi.cr.comments"

  it("opens a context/editor pair and closes both through the public interface", function()
    local source_win = vim.api.nvim_get_current_win()
    local before = #vim.api.nvim_list_wins()

    comments.add {
      file = "src/example.lua",
      line = 4,
      end_line = 4,
      snippet = "one\ntwo\nthree",
      context = {
        lines = { "one", "two", "three" },
        start_line = 3,
        end_line = 5,
        anchor_line = 4,
      },
    }

    assert.equal(before + 2, #vim.api.nvim_list_wins())
    assert.is_not.equal(source_win, vim.api.nvim_get_current_win())

    comments.close_ui "test"
    assert.equal(before, #vim.api.nvim_list_wins())
    assert.equal(source_win, vim.api.nvim_get_current_win())
  end)

  local function open_editor()
    comments.add {
      file = "src/example.lua",
      line = 4,
      end_line = 4,
      snippet = "one",
      context = { lines = { "one" }, start_line = 4, end_line = 4, anchor_line = 4 },
    }
    return vim.api.nvim_get_current_buf()
  end

  -- 只看 buffer-local 映射：全局映射（用户 config / 插件）与本模块无关，
  -- 断言要用 nvim_buf_get_keymap 而不是 maparg（后者会回落到全局）。
  local function buffer_keymap(buf, mode, lhs)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      if map.lhs:lower() == lhs:lower() then
        return map
      end
    end
    return nil
  end

  -- headless 下无法稳定模拟 insert 模式，改为断言映射接线：
  -- <Esc> 不能占用（保持 vim 默认 insert -> normal），取消只在 normal 模式用 q。
  it("leaves <Esc> unmapped so it only exits insert mode", function()
    local source_win = vim.api.nvim_get_current_win()
    local editor_buf = open_editor()
    local wins_open = #vim.api.nvim_list_wins()

    assert.is_nil(buffer_keymap(editor_buf, "i", "<Esc>"))
    assert.is_nil(buffer_keymap(editor_buf, "n", "<Esc>"))
    assert.equal(editor_buf, vim.api.nvim_get_current_buf())
    assert.equal(wins_open, #vim.api.nvim_list_wins())

    comments.close_ui "test"
    assert.equal(source_win, vim.api.nvim_get_current_win())
  end)

  it("cancels the annotation with q in normal mode, and frees <C-c>", function()
    local before = #vim.api.nvim_list_wins()

    local editor_buf = open_editor()
    assert.is_nil(buffer_keymap(editor_buf, "i", "<C-c>"))
    assert.is_nil(buffer_keymap(editor_buf, "n", "<C-c>"))
    local map = buffer_keymap(editor_buf, "n", "q")
    assert.is_not_nil(map)
    assert.equal("Cancel Pi CR annotation", map.desc)

    assert.equal(before + 2, #vim.api.nvim_list_wins())
    map.callback()
    assert.equal(before, #vim.api.nvim_list_wins())
  end)

  -- blink.cmp 在 InsertEnter 时按 buffer 重绑 <CR>（select_and_accept），
  -- 会盖掉本 buffer 的 submit；vim.b.completion = false 是它官方的开关。
  it("disables completion in the editor buffer so <CR> submits", function()
    local editor_buf = open_editor()

    assert.equal(false, vim.b[editor_buf].completion)
    local map = buffer_keymap(editor_buf, "i", "<CR>")
    assert.is_not_nil(map)
    assert.equal("Submit Pi CR annotation", map.desc)

    comments.close_ui "test"
  end)

  -- ---------------------------------------------------------------------
  -- Editing an existing annotation
  -- ---------------------------------------------------------------------

  local function press(buf, mode, lhs)
    local map = buffer_keymap(buf, mode, lhs)
    assert.is_not_nil(map, "missing mapping " .. lhs .. " in " .. mode)
    map.callback()
  end

  local function submit(text)
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
    press(buf, "i", "<CR>")
  end

  local function artifact_rows(path)
    local rows = {}
    for _, line in ipairs(vim.fn.readfile(path)) do
      rows[#rows + 1] = vim.json.decode(line)
    end
    return rows
  end

  local function fresh_session()
    comments.clear_all()
    local artifact = vim.fn.tempname() .. ".jsonl"
    comments.set_config { annotationsPath = artifact }
    return artifact
  end

  local function add_comment(file, line, snippet)
    comments.add {
      file = file,
      line = line,
      end_line = line,
      snippet = snippet,
      context = { lines = { snippet }, start_line = line, end_line = line, anchor_line = line },
    }
  end

  it("prefills the popup and updates the annotation in place on <CR>", function()
    local artifact = fresh_session()
    add_comment("src/a.lua", 3, "line three")
    submit "first body"
    assert.equal(1, #comments.comments)
    local id = comments.comments[1].id

    assert.is_true(comments.edit_by_id(id))
    local buf = vim.api.nvim_get_current_buf()
    assert.same({ "first body" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))

    press(buf, "i", "<Tab>") -- note -> question
    submit "second body\nwith a second line"

    assert.equal(1, #comments.comments)
    assert.equal(id, comments.comments[1].id)
    assert.equal("second body\nwith a second line", comments.comments[1].comment)
    assert.equal("question", comments.comments[1].type)

    local rows = artifact_rows(artifact)
    assert.equal(1, #rows)
    assert.equal("second body\nwith a second line", rows[1].comment)
    assert.equal("question", rows[1].type)
    assert.equal("src/a.lua", rows[1].file)
  end)

  it("leaves the annotation untouched when the edit is cancelled", function()
    local artifact = fresh_session()
    local wins_before = #vim.api.nvim_list_wins()
    add_comment("src/a.lua", 3, "line three")
    submit "kept body"
    assert.equal(1, #comments.comments)

    assert.is_true(comments.edit_by_id(comments.comments[1].id))
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "discarded draft" })
    press(buf, "n", "q")

    assert.equal(wins_before, #vim.api.nvim_list_wins())
    assert.equal(1, #comments.comments)
    assert.equal("kept body", comments.comments[1].comment)
    assert.equal(1, #artifact_rows(artifact))
    assert.equal("kept body", artifact_rows(artifact)[1].comment)
  end)

  it("rewrites the artifact so deleted annotations leave no stale row", function()
    local artifact = fresh_session()
    add_comment("src/a.lua", 3, "line three")
    submit "keep me"
    add_comment("src/b.lua", 9, "line nine")
    submit "delete me"
    assert.equal(2, #comments.comments)
    assert.equal(2, #artifact_rows(artifact))

    comments.delete_by_id(comments.comments[2].id)

    local rows = artifact_rows(artifact)
    assert.equal(1, #rows)
    assert.equal("keep me", rows[1].comment)
  end)
end)
