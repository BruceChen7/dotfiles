require("avante").setup {
  -- add any opts here
  behaviour = {
    auto_suggestions = false,
    -- auto_set_keymaps = false,
    enable_cursor_planning_mode = true, -- enable cursor planning mod
  },
  mode = "legacy",
  -- mode = "agentic",
  -- provider = "chatgpt",
  provider = "freedeepseek",
  -- provider = "gemini",
  -- provider = "openrouter",
  -- cursor_applying_provider = "groq",
  cursor_applying_provider = "kimik2turbo",
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
  providers = {
    gemini = {
      -- proxy = "https://api-proxy.me/gemini",
      endpoint = "https://api-proxy.me/gemini/v1beta/models",
      model = "gemini-2.5-pro",
      __inherited_from = "gemini",
      api_key_name = "GEMINI_API_KEY",
    },

    openrouter = {
      __inherited_from = "openai",
      endpoint = "https://openrouter.ai/api/v1",
      api_key_name = "OPENROUTER_API_KEY",
      model = "deepseek/deepseek-r1:free",
      -- model = "deepseek/deepseek-chat-v3-0324:free",
      disable_tools = true,
      extra_request_body = {
        temperature = 0,
      },
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
      extra_request_body = {
        temperature = 0,
      },
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
      disable_tools = true,
    },
    qwen3 = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      -- model = "deepseek-v3-0324",
      model = "qwen3-235b-a22b",
      max_tokens = 24000, -- remember to increase this value, otherwise it will stop generating halfway
      -- https://github.com/Aider-AI/aider/pull/3908
      extra_request_body = {
        temperature = 0,
      },
      disable_tools = true,
    },
    freedeepseek = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      -- model = "deepseek-v3-0324",
      -- model = "deepseek-v3-0324",
      -- model = "deepseek-r1-0528",
      model = "kimi-k2",
      -- https://ai.nahcrof.com/pricing
      max_tokens = 134000,
      disable_tools = true,
      extra_request_body = {
        temperature = 0.7,
      },
    },
    kimik2turbo = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      -- model = "deepseek-v3-0324",
      -- model = "deepseek-v3-0324",
      -- model = "deepseek-r1-0528",
      model = "kimi-k2-turbo",
      -- https://ai.nahcrof.com/pricing
      max_tokens = 134000,
      disable_tools = true,
      extra_request_body = {
        temperature = 0.7,
      },
    },
    -- https://linux.do/t/topic/783000
    chatgpt = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://api-0711-node144.be-a.dev/api/layers/openai/bulk",
      model = "gpt-4.1",
      -- https://ai.nahcrof.com/pricing
      -- max_tokens = 134000,
      -- max_tokens = 134000,
      disable_tools = true,
      extra_request_body = {
        temperature = 0,
      },
    },
  },
}
