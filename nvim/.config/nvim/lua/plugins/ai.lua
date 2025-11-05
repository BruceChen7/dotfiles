return {
  {
    "folke/sidekick.nvim",
    opts = {
      -- add any options here
      cli = {
        mux = {
          backend = "tmux",
          enabled = false,
        },
        tools = {
          ccr = {
            cmd = { "ccr", "code" },
          },
          droid = {
            cmd = { "droid" },
          },
        },
      },
    },
    nes = {
      enabled = false,
    },
    keys = {
      {
        "<space>aa",
        function()
          require("sidekick.cli").toggle { focus = true }
        end,
        desc = "Sidekick Toggle CLI",
        mode = { "n", "t", "i", "x" },
      },
      {
        "<space>as",
        function()
          require("sidekick.cli").select()
        end,
        -- Or to select only installed tools:
        -- require("sidekick.cli").select({ filter = { installed = true } })
        desc = "Select CLI",
      },
      {
        "<space>at",
        function()
          require("sidekick.cli").send { msg = "{this}" }
        end,
        mode = { "x", "n" },
        desc = "Send This",
      },
      {
        "<space>af",
        function()
          require("sidekick.cli").send { msg = "{file}" }
        end,
        desc = "Send File",
      },
      {
        "<space>av",
        function()
          require("sidekick.cli").send { msg = "{selection}" }
        end,
        mode = { "x" },
        desc = "Send Visual Selection",
      },
      {
        "<space>ap",
        function()
          require("sidekick.cli").prompt()
        end,
        mode = { "n", "x" },
        desc = "Sidekick Select Prompt",
      },
      {
        "<space>ar",
        function()
          require("sidekick.cli").toggle { name = "ccr", focus = true }
        end,
        desc = "Sidekick Toggle claude code router",
      },
      {
        "<space>ad",
        function()
          require("sidekick.cli").toggle { name = "droid", focus = true }
        end,
        desc = "Sidekick Toggle Droid",
      },
    },
  },
}
