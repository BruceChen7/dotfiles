local pack = require "core.pack"
local gh = pack.github

return {
  name = "ai",
  specs = {
    { src = gh "folke/sidekick.nvim" },
    { src = gh "folke/snacks.nvim" },
  },
  setup = function()
    pack.setup_config("snacks.nvim", "config/snacks")

    pack.safe_call("sidekick", function()
      pack.packadd "sidekick.nvim"
      require("sidekick").setup {
        cli = {
          mux = {
            backend = "tmux",
            enabled = false,
          },
          tools = {
            ccr = { cmd = { "ccr", "code" } },
            droid = { cmd = { "droid" } },
            pi = { cmd = { "pi" } },
          },
        },
        nes = {
          enabled = false,
        },
      }
    end)

    vim.keymap.set({ "n", "t", "i", "x" }, "<space>aa", function()
      require("sidekick.cli").toggle { focus = true }
    end, { desc = "Sidekick Toggle CLI" })
    vim.keymap.set("n", "<space>as", function()
      require("sidekick.cli").select()
    end, { desc = "Select CLI" })
    vim.keymap.set({ "x", "n" }, "<space>at", function()
      require("sidekick.cli").send { msg = "{this}" }
    end, { desc = "Send This" })
    vim.keymap.set("n", "<space>af", function()
      require("sidekick.cli").send { msg = "{file}" }
    end, { desc = "Send File" })
    vim.keymap.set("x", "<space>av", function()
      require("sidekick.cli").send { msg = "{selection}" }
    end, { desc = "Send Visual Selection" })
    vim.keymap.set({ "n", "x" }, "<space>ap", function()
      require("sidekick.cli").prompt()
    end, { desc = "Sidekick Select Prompt" })
    vim.keymap.set("n", "<space>ar", function()
      require("sidekick.cli").toggle { name = "ccr", focus = true }
    end, { desc = "Sidekick Toggle claude code router" })
    vim.keymap.set("n", "<space>ad", function()
      require("sidekick.cli").toggle { name = "droid", focus = true }
    end, { desc = "Sidekick Toggle Droid" })
  end,
}
