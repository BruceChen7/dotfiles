require("avante").setup {
  -- add any opts here
  behaviour = {
    auto_suggestions = false,
    -- auto_set_keymaps = false,
    enable_cursor_planning_mode = false, -- enable cursor planning mode!
  },
  provider = "deepseek",
  -- provider = "freedeepseek",
  cursor_applying_provider = "groq",
  -- auto_suggestions_provider = "deepseek",
  mappings = {
    ask = "\\ak",
    edit = "\\am",
    refresh = "\\ar",
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
  },
  vendors = {
    deepseek = {
      __inherited_from = "openai",
      api_key_name = "DEEPSEEK_API_KEY",
      endpoint = "https://api.deepseek.com",
      model = "deepseek-chat",
    },
    groq = { -- define groq provider
      __inherited_from = "openai",
      api_key_name = "GROQ_API_KEY",
      endpoint = "https://api.groq.com/openai/v1/",
      model = "llama-3.3-70b-versatile",
      max_tokens = 32768, -- remember to increase this value, otherwise it will stop generating halfway
    },
    freedeepseek = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      model = "deepseek-r1",
    },
  },
}
