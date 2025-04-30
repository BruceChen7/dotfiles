require("avante").setup {
  -- add any opts here
  behaviour = {
    auto_suggestions = false,
    -- auto_set_keymaps = false,
    enable_cursor_planning_mode = true, -- enable cursor planning mod
  },
  -- provider = "deepseek",
  provider = "freedeepseek",
  -- provider = "openrouter",
  -- cursor_applying_provider = "groq",
  cursor_applying_provider = "real_groq",
  memory_summary_provider = "freedeepseek",
  -- cursor_applying_provider = "week_operouter",
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
    cancel = {
      normal = { "<C-c>", "<Esc>", "q" },
      insert = { "<C-c>" },
    },
    sidebar = {
      apply_all = "A",
      apply_cursor = "a",
      retry_user_request = "r",
      edit_user_request = "e",
      switch_windows = "<Tab>",
      reverse_switch_windows = "<S-Tab>",
      remove_file = "d",
      add_file = "@",
      close = { "q" },
      close_from_input = nil, -- e.g., { normal = "<Esc>", insert = "<C-d>" }
    },
  },
  vendors = {
    openrouter = {
      __inherited_from = "openai",
      endpoint = "https://openrouter.ai/api/v1",
      api_key_name = "OPENROUTER_API_KEY",
      -- model = "google/gemini-2.5-pro-exp-03-25:free",
      -- model = "deepseek/deepseek-r1:free",
      model = "deepseek/deepseek-chat-v3-0324:free",
      disable_tools = true,
      temperature = 0,
    },

    week_operouter = {
      __inherited_from = "openai",
      endpoint = "https://openrouter.ai/api/v1",
      api_key_name = "OPENROUTER_API_KEY",
      -- model = "google/gemini-2.5-pro-exp-03-25:free",
      -- model = "deepseek/deepseek-r1:free",
      model = "meta-llama/llama-3.3-70b-instruct:free",
      disable_tools = true,
      -- temperature = 0,
    },

    deepseek = {
      __inherited_from = "openai",
      api_key_name = "DEEPSEEK_API_KEY",
      endpoint = "https://api.deepseek.com",
      model = "deepseek-chat",
      max_tokens = 8192, -- remember to increase this value, otherwise it will stop generating halfway
      temperature = 0,
    },
    groq = { -- define groq provider
      __inherited_from = "openai",
      -- api_key_name = "GROQ_API_KEY",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://api.groq.com/openai/v1/",
      model = "llama3.3-70b",
      max_tokens = 32768, -- remember to increase this value, otherwise it will stop generating halfway
    },
    real_groq = { -- define groq provider
      __inherited_from = "openai",
      api_key_name = "GROQ_API_KEY",
      endpoint = "https://api-proxy.me/groq/v1",
      model = "llama-3.3-70b-versatile",
      max_tokens = 32768, -- remember to increase this value, otherwise it will stop generating halfway
    },
    freedeepseek = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      model = "deepseek-v3-0324",
      max_tokens = 8192, -- remember to increase this value, otherwise it will stop generating halfway
      temperature = 0,
    },
  },
}
