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

  -- headless 下无法稳定模拟 insert 模式，改为断言映射接线：
  -- <Esc> 不能占用（保持 vim 默认 insert -> normal），<C-c> 在 i/n 两模式都接到 cancel。
  it("leaves <Esc> unmapped so it only exits insert mode", function()
    local source_win = vim.api.nvim_get_current_win()
    local editor_buf = open_editor()
    local wins_open = #vim.api.nvim_list_wins()

    assert.is_true(vim.tbl_isempty(vim.fn.maparg("<Esc>", "i", false, true)))
    assert.is_true(vim.tbl_isempty(vim.fn.maparg("<Esc>", "n", false, true)))
    assert.equal(editor_buf, vim.api.nvim_get_current_buf())
    assert.equal(wins_open, #vim.api.nvim_list_wins())

    comments.close_ui "test"
    assert.equal(source_win, vim.api.nvim_get_current_win())
  end)

  it("cancels the annotation with <C-c> in insert and normal mode", function()
    local before = #vim.api.nvim_list_wins()

    open_editor()
    for _, mode in ipairs { "i", "n" } do
      local map = vim.fn.maparg("<C-c>", mode, false, true)
      assert.equal("<C-C>", map.lhs)
      assert.equal(1, map.buffer)
      assert.equal("Cancel Pi CR annotation", map.desc)
    end
    assert.equal(before + 2, #vim.api.nvim_list_wins())
    vim.fn.maparg("<C-c>", "n", false, true).callback()
    assert.equal(before, #vim.api.nvim_list_wins())
  end)
end)
