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
end)
