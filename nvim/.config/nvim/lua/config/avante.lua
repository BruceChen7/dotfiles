require("avante").setup {
  -- add any opts here

  behaviour = {
    auto_suggestions = false,
  },
  mode = "legacy",
  -- provider = "chatgpt",
  provider = "qwen3",
  memory_summary_provider = "glm45",
  mappings = {
    ask = "\\ak",
    edit = "\\am",
    refresh = "\\ar",
    focus = "\\af",
    new_ask = "\\an",
    stop = "\\as",

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
      suggestion = "\\aS",
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
      next_prompt = "]p",
      prev_prompt = "[p",
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
    qwen3 = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      -- model = "deepseek-v3-0324",
      model = "qwen3-coder",
      max_tokens = 134000, -- remember to increase this value, otherwise it will stop generating halfway
      disable_tools = true,
      -- https://github.com/Aider-AI/aider/pull/3908
      extra_request_body = {
        temperature = 0.7,
      },
    },
    glm45 = {
      __inherited_from = "openai",
      api_key_name = "FREE_DEEPSEEK_API_KEY",
      endpoint = "https://ai.nahcrof.com/v2",
      model = "glm-4.5",
      -- https://ai.nahcrof.com/pricing
      max_tokens = 134000,
      -- disable_tools = true,
      extra_request_body = {
        -- temperature = 0.7,
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
  },
}
