require("avante").setup {
  -- add any opts here
  behaviour = {
    auto_suggestions = false,
    -- auto_set_keymaps = false,
    enable_cursor_planning_mode = false, -- enable cursor planning mod
  },
  -- provider = "deepseek",
  provider = "freedeepseek",
  cursor_applying_provider = "groq",
  -- auto_suggestions_provider = "deepseek",
  mappings = {
    ask = "\\ak",
    edit = "\\am",
    refresh = "\\ar",
    focus = "\\af",
    select_history = "\\ah", -- Select history command
    select_model = "\\a?", -- Select model command

    --- @class AvanteConflictMappings
    diff = {
      ours = "\\co",
      theirs = "\\ct",
      none = "\\c0",
      both = "\\cb",
      next = "]x",
      prev = "[x",
    },
    jump = {
      next = "]]",
      prev = "[[",
    },
    submit = {
      normal = "<CR>",
      insert = "<C-s>",
    },
    suggestion = {
      accept = "<M-j>",
      -- next = "<\\n>",
      -- prev = "<[\\p>",
      -- dismiss = "<\\]>",
    },
    toggle = {
      default = "\\at",
      debug = "\\ad",
      hint = "\\ah",
      suggestion = "\\as",
      repomap = "\\aR",
    },
  },
  vendors = {
    deepseek = {
      __inherited_from = "openai",
      api_key_name = "DEEPSEEK_API_KEY",
      endpoint = "https://api.deepseek.com",
      model = "deepseek-chat",
      max_tokens = 8192, -- remember to increase this value, otherwise it will stop generating halfway
    },
    groq = { -- define groq provider
      __inherited_from = "openai",
      -- api_key_name = "GROQ_API_KEY",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      -- endpoint = "https://api.groq.com/openai/v1/",
      endpoint = "https://ai.nahcrof.com/v2",
      model = "llama3.3-70b",
      max_tokens = 32768, -- remember to increase this value, otherwise it will stop generating halfway
    },
    freedeepseek = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      model = "deepseek-v3-0324",
      max_tokens = 8192, -- remember to increase this value, otherwise it will stop generating halfway
    },
  },
}
