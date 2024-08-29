require("codecompanion").setup {
  opts = {
    log_level = "INFO",
    -- log_level = "TRACE",
  },
  adapters = {
    deepseek = require("codecompanion.adapters").extend("openai", {
      env = {
        api_key = os.getenv "DEEPSEEK_API_KEY",
      },
      url = "https://api.deepseek.com/beta/chat/completions",
      schema = {
        model = {
          default = "deepseek-chat",
          choices = {
            "deepseek-coder",
            "deepseek-chat",
          },
        },
        max_token = {
          default = 8192,
        },
        temperature = {
          default = 1,
        },
      },
    }),
  },
  strategies = {
    chat = {
      adapter = "deepseek",
    },
    inline = {
      adapter = "deepseek",
    },
    agent = {
      adapter = "deepseek",
      tools = {
        opts = {
          auto_submit_errors = false,
          auto_submit_success = false,
        },
      },
    },
  },
  display = {
    inline = {
      diff = {
        enabled = true,
      },
    },
    chat = {
      show_settings = true,
    },
  },
}
