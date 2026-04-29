local pack = require "core.pack"
local gh = pack.github

return {
  name = "files",
  specs = {
    { src = gh "stevearc/oil.nvim" },
    { src = gh "bloznelis/before.nvim" },
    { src = gh "willothy/flatten.nvim" },
  },
  setup = function()
    pack.setup_config("oil.nvim", "config/oil")

    pack.safe_call("before.nvim", function()
      pack.packadd "before.nvim"
      local before = require "before"
      before.setup()
      vim.keymap.set("n", "<space>g;", before.jump_to_last_edit, { desc = "Jump to last edit position" })
      vim.keymap.set("n", "<space>g,", before.jump_to_next_edit, { desc = "Jump to next edit position" })
      vim.keymap.set("n", "<space>gq", before.show_edits_in_quickfix, { desc = "Show edits in quickfix" })
    end)

    pack.safe_call("flatten.nvim", function()
      pack.packadd "flatten.nvim"
      require("flatten").setup()
    end)
  end,
}
