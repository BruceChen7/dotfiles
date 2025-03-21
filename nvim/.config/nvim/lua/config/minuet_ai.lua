-- bubble sort
require("minuet").setup {
  provider = "openai_compatible",
  provider_options = {
    openai_compatible = {
      end_point = "https://ai.nahcrof.com/v2",
      api_key = "FREE_DEEPSEEK_API_KEY",
      name = "deepseek-v3",
      model = "deepseek-v3",
      optional = {
        max_tokens = 256,
        top_p = 0.9,
      },
    },
  },

  virtualtext = {
    auto_trigger_ft = { "go" },
    keymap = {
      -- accept whole completion
      accept = "<c-y>",
      -- accept one line
      accept_line = "<A-a>",
      -- accept n lines (prompts for number)
      -- e.g. "A-z 2 CR" will accept 2 lines
      accept_n_lines = "<A-z>",
      -- Cycle to prev completion item, or manually invoke completion
      prev = "<Up>",
      -- Cycle to next completion item, or manually invoke completion
      next = "<Down>",
      dismiss = "<c-e>",
    },
  },
  notify = "debug",
}
